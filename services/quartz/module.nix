# Quartz static site generation for selective Obsidian publishing.
#
# Pipeline (no self-hosted web server):
#   1. Private vault repo (Obsidian Git + LiveSync) is cloned on the server.
#   2. A curated build input allowlist (markdown + `5 ~ Resources/attachments`)
#      is staged into a temp dir so the Assets emitter can never leak other
#      non-markdown files (PDFs, Excalidraw, .obsidian, scratch).
#   3. Patched Quartz builds the site.
#   4. ONLY the generated `public/` tree is committed + pushed to the public
#      GitHub Pages repo (`gh-pages` branch). Raw private notes never leave
#      the server.
#
# The patched source, filter plugin, and config are overlaid at build time from
# `./quartz.config.ts` and `./quartz/plugins/filters/explicit.ts` onto the
# `quartz` flake input.

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cfg = config.services.quartz;

  dataDir = cfg.dataDir;
  srcDir = "${dataDir}/src";
  vaultDir = cfg.vaultDir;
  siteDir = cfg.siteDir;
  stageDir = "${dataDir}/stage";
  outDir = cfg.outDir;
  stateDir = "${dataDir}/state";

  node = cfg.nodejs;

  gitSshCommand =
    if cfg.gitSshKey == null then
      "${pkgs.openssh}/bin/ssh -o StrictHostKeyChecking=accept-new"
    else
      "${pkgs.openssh}/bin/ssh -i ${cfg.gitSshKey} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new";

  # Patched Quartz checkout: pristine source + our config + filter overlay.
  quartzSrc = pkgs.stdenv.mkDerivation {
    name = "quartz-v4-overlay";
    src = inputs.quartz;
    dontUnpack = true;
    installPhase = ''
      mkdir -p "$out"
      cp -r --no-preserve=mode "$src/." "$out/"
      install -m 0644 ${./quartz.config.ts} "$out/quartz.config.ts"
      install -m 0644 ${./quartz/plugins/filters/explicit.ts} "$out/quartz/plugins/filters/explicit.ts"
    '';
    dontFixup = true;
  };

  q = lib.escapeShellArg;
  p = lib.escapeShellArg;

  buildScript = pkgs.writeShellScript "quartz-build" ''
    set -euo pipefail

    export GIT_SSH_COMMAND=${q gitSshCommand}

    SRC=${q srcDir}
    VAULT=${q vaultDir}
    SITE=${q siteDir}
    STAGE=${q stageDir}
    OUT=${q outDir}
    STATE=${q stateDir}
    NODE=${q node}/bin/node

    vaultBranch=${q cfg.vaultBranch}
    siteBranch=${q cfg.siteBranch}
    vaultRepo=${q cfg.vaultRepo}
    siteRepo=${q cfg.siteRepo}

    mkdir -p "$STATE"

    # --- 1. Sync private vault checkout ------------------------------------
    if [ ! -d "$VAULT/.git" ]; then
      echo "cloning vault $vaultRepo"
      git clone "$vaultRepo" "$VAULT"
    fi
    git -C "$VAULT" fetch origin "$vaultBranch" 2>/dev/null || {
      echo "git fetch failed (offline?) — skipping build"
      exit 0
    }
    newHead=$(git -C "$VAULT" rev-parse -q --verify "origin/$vaultBranch" 2>/dev/null || true)
    if [ -z "$newHead" ]; then
      echo "no remote branch origin/$vaultBranch — skipping build"
      exit 0
    fi

    # Skip rebuild when the vault has not advanced since the last build.
    lastHead=$(cat "$STATE/.last-commit" 2>/dev/null || true)
    if [ -n "$lastHead" ] && [ "$lastHead" = "$newHead" ]; then
      echo "vault unchanged ($newHead) — nothing to do"
      exit 0
    fi

    git -C "$VAULT" reset --hard "$newHead"
    git -C "$VAULT" clean -fdq

    # --- 2. Stage a curated build input ------------------------------------
    # Allowlist: directories, ALL markdown (the filter decides what publishes),
    # and the attachments folder (so embedded media resolves). Everything else —
    # personal PDFs, Excalidraw, .obsidian, scratch files — never enters the build.
    rm -rf "$STAGE"
    mkdir -p "$STAGE/5 ~ Resources/attachments"
    rsync -a \
      --exclude='.git/' \
      --include='*/' --include='*.md' --exclude='*' \
      "$VAULT/" "$STAGE/"
    if [ -d "$VAULT/5 ~ Resources/attachments" ]; then
      rsync -a "$VAULT/5 ~ Resources/attachments/" "$STAGE/5 ~ Resources/attachments/"
    fi

    # --- 3. Install dependencies (only when the lockfile changed) -----------
    if ! cmp -s "$SRC/package-lock.json" "$STATE/.npmlock"; then
      echo "installing npm dependencies"
      (cd "$SRC" && npm ci --no-audit --no-fund)
      cp "$SRC/package-lock.json" "$STATE/.npmlock"
    fi

    # --- 4. Build ----------------------------------------------------------
    rm -rf "$OUT"
    mkdir -p "$OUT"
    echo "building site at $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    (cd "$SRC" && "$NODE" quartz/bootstrap-cli.mjs build -d "$STAGE" -o "$OUT")

    # --- 5. Publish ONLY the built site to the Pages repo ------------------
    if [ ! -d "$SITE/.git" ]; then
      git clone "$siteRepo" "$SITE" 2>/dev/null || {
        mkdir -p "$SITE"
        git -C "$SITE" init -b "$siteBranch"
        git -C "$SITE" remote add origin "$siteRepo"
      }
    fi
    git -C "$SITE" fetch origin "$siteBranch" 2>/dev/null || true
    git -C "$SITE" checkout -B "$siteBranch" "origin/$siteBranch" 2>/dev/null \
      || git -C "$SITE" switch --orphan "$siteBranch" 2>/dev/null \
      || true

    rsync -a --delete "$OUT/" "$SITE/"
    git -C "$SITE" add -A
    if ! git -C "$SITE" diff --cached --quiet; then
      git -C "$SITE" \
        -c user.name="quartz-builder" \
        -c user.email="quartz@argon.invalid" \
        commit -m "quartz rebuild $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    fi
    git -C "$SITE" push --set-upstream origin "$siteBranch"

    echo "$newHead" > "$STATE/.last-commit"
    echo "done — site pushed to $siteRepo ($siteBranch)"
  '';
in {
  options.services.quartz = {
    enable = lib.mkEnableOption "automated Quartz publishing to GitHub Pages";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/quartz";
      description = "Runtime data for the Quartz build pipeline.";
    };

    vaultRepo = lib.mkOption {
      type = lib.types.str;
      default = "git@github.com:ftbento/vault.git";
      description = "Private repository Obsidian Git pushes the vault to.";
    };

    vaultBranch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Branch of the vault repository to track.";
    };

    vaultDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/quartz/vault";
      description = "Local clone of the private vault repository.";
    };

    siteRepo = lib.mkOption {
      type = lib.types.str;
      default = "git@github.com:ftbento/notes.git";
      description = "Public repository served by GitHub Pages.";
    };

    siteBranch = lib.mkOption {
      type = lib.types.str;
      default = "gh-pages";
      description = "Branch of the Pages repository that gets served.";
    };

    siteDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/quartz/site";
      description = "Local checkout that the built site is pushed from.";
    };

    outDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/quartz/public";
      description = "Directory Quartz writes the static site into.";
    };

    gitSshKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default =
        if lib.hasAttrByPath [ "age" "secrets" "github-ftbento" ] config then
          config.age.secrets.github-ftbento.path
        else
          null;
      description = "SSH private key used to access GitHub for vault pull + site push.";
    };

    nodejs = lib.mkOption {
      type = lib.types.attrs;
      default = pkgs.nodejs_22;
      description = "Node.js (>= 22) used to run the Quartz build.";
    };

    timer.onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "*:0/5";
      description = "systemd timer schedule; polls the vault repo for new commits.";
    };
  };

  config =
    lib.mkIf cfg.enable {
      assertions = [{
        assertion = cfg.vaultRepo != "" && cfg.siteRepo != "";
        message = "services.quartz.vaultRepo and services.quartz.siteRepo must not be empty.";
      }];

      # Seed / apply the patched Quartz source on each NixOS rebuild.
      system.activationScripts.quartz = lib.mkAfter ''
        mkdir -p ${dataDir}
        rsync -a \
          --delete \
          --exclude='node_modules' \
          ${quartzSrc}/ ${q srcDir}/
        chmod -R u+w ${q srcDir}
      '';

      systemd.services.quartz-build = {
        description = "Build selective Obsidian notes with Quartz and publish to GitHub Pages";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        path = with pkgs; [ node git openssh rsync coreutils gnused ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = buildScript;
          StateDirectory = "quartz";
          UMask = "0027";
          PrivateTmp = true;
          Nice = 10;
        };
      };

      systemd.timers.quartz-build = {
        description = "Periodically check the vault repo for new commits";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.timer.onCalendar;
          Persistent = true;
          RandomizedDelaySec = "60";
        };
      };
    };
}