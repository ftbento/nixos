# odysseus — a self-hosted AI workspace (chat, agents, email, research, notes).
#
# Upstream ships a multi-service docker compose stack (odysseus + searxng +
# chromadb + ntfy). We run the *minimal* `odysseus` container only for now and
# point its LLM provider at LiteLLM on the Docker host (host.docker.internal),
# so every model alias (daily/smart/tools/ajax/local) fans out from there.
#
# The image is built from a pinned upstream source tree on first service start
# (`docker compose up -d --build`). Compose layer-caches, so subsequent boots
# reuse the image unless `rev` changes. The web UI binds to a single address so
# it stays where you put it — pass the Tailscale IP to keep it tailnet-only.

{ config, lib, pkgs, ... }:

let
  cfg = config.services.odysseus;

  src = pkgs.fetchgit {
    url = "https://github.com/odysseus-dev/odysseus.git";
    rev = cfg.rev;
    hash = cfg.hash;
  };

  origins = lib.concatStringsSep "," cfg.allowedOrigins;

  # PUID/PGID are resolved at start time (`id -u`/`id -g`) so they always match
  # the allocated system user without depending on eval-phase id assignment.
  dockerCompose = lib.getExe pkgs.docker-compose;
  composeArgs = "-p odysseus -f ${composeFile}";

  # A non-wildcard bind address (e.g. a Tailscale IP) may not exist yet when
  # Docker auto-starts the container at boot; the port mapping is then silently
  # dropped and `compose up` won't reconcile it. Wait for the address, then
  # force-recreate so the mapping is applied for real.
  waitForBind = ''
    addr=${lib.escapeShellArg cfg.bindAddress}
    case "$addr" in
      0.0.0.0 | 127.0.0.1 | "") : ;;
      *)
        n=0
        while [ "$n" -lt 60 ]; do
          if ${lib.getExe' pkgs.iproute2 "ip"} -o addr show 2>/dev/null | grep -q "inet $addr/"; then
            break
          fi
          ${lib.getExe' pkgs.coreutils "sleep"} 2
          n=$((n + 1))
        done
        ;;
    esac
  '';

  upScript = pkgs.writeShellScript "odysseus-up" ''
    export PUID="$(id -u '${cfg.user}')"
    export PGID="$(id -g '${cfg.group}')"
    ${lib.optionalString cfg.waitForBindAddress waitForBind}
    exec ${dockerCompose} ${composeArgs} up -d --build --force-recreate
  '';
  downScript = pkgs.writeShellScript "odysseus-down" ''
    exec ${dockerCompose} ${composeArgs} down
  '';

  # Idempotent, by base_url. Runs inside the container (only place with both
  # the app's Fernet key at data/.app_key and the cryptography package), so the
  # API key gets encrypted through the app's own ORM — a raw sqlite insert would
  # store plaintext the app can't read. Also refreshes `cached_models` on every
  # start: proxy-kind endpoints don't auto-refresh, so this keeps Odysseus's
  # model list in sync with LiteLLM whenever the model_list changes.
  seedPy = pkgs.writeText "odysseus-seed-endpoints.py" ''
    import json
    import os
    import sys
    import time
    import uuid

    url = os.environ["ODYSSEUS_EP_URL"]
    name = os.environ["ODYSSEUS_EP_NAME"]
    key = os.environ.get(os.environ.get("ODYSSEUS_EP_KEYENV", ""), "")

    last = None
    for attempt in range(100):
        try:
            from core.database import ModelEndpoint, SessionLocal

            db = SessionLocal()
            try:
                ep = db.query(ModelEndpoint).filter(ModelEndpoint.base_url == url).first()
                if ep is None:
                    ep = ModelEndpoint(
                        id=str(uuid.uuid4())[:8],
                        name=name,
                        base_url=url,
                        api_key=key,
                        is_enabled=True,
                    )
                    db.add(ep)
                try:
                    from routes.model_routes import _normalize_base, _probe_endpoint

                    models = _probe_endpoint(_normalize_base(url), key, timeout=20)
                    if models:
                        ep.cached_models = json.dumps(models)
                except Exception as exc:
                    print("probe skipped:", exc, file=sys.stderr, flush=True)
                db.commit()
                print("endpoint ready:", name, url)
                break
            finally:
                db.close()
        except Exception as exc:
            last = exc
            print("retry:", exc, file=sys.stderr, flush=True)
            time.sleep(3)
    else:
        print("FAILED:", last, file=sys.stderr)
        sys.exit(1)
  '';

  seedScript = pkgs.writeShellScript "odysseus-seed-endpoints" (
    "set -eu\n"
    + lib.concatMapStringsSep "\n" (ep:
      "${lib.getExe pkgs.docker} exec -i"
      + " -e ${ep.apiKeyEnv}"
      + " -e ODYSSEUS_EP_NAME=${lib.escapeShellArg ep.name}"
      + " -e ODYSSEUS_EP_URL=${lib.escapeShellArg ep.url}"
      + " -e ODYSSEUS_EP_KEYENV=${ep.apiKeyEnv}"
      + " odysseus python3 - < ${seedPy}"
    ) cfg.seedEndpoints
    + "\n"
  );

  # Minimal compose: just the app. `OPENAI_API_KEY` is pulled from the
  # `LITELLM_MASTER_KEY` env var (fed in via EnvironmentFile, never written to
  # the store); `ODYSSEUS_ADMIN_PASSWORD` is passed straight through from the
  # same mechanism.
  composeFile = pkgs.writeText "odysseus-compose.yml" ''
    services:
      odysseus:
        build:
          context: ${src}
        image: odysseus:local
        container_name: odysseus
        ports:
          - "${cfg.bindAddress}:${toString cfg.port}:7000"
        volumes:
          - ${cfg.dataDir}/data:/app/data
          - ${cfg.dataDir}/logs:/app/logs
        extra_hosts:
          - "host.docker.internal:host-gateway"
        environment:
          - LLM_HOST=${cfg.llmHost}
          - OPENAI_API_KEY=''${LITELLM_MASTER_KEY}
          - AUTH_ENABLED=${lib.boolToString cfg.authEnabled}
          - LOCALHOST_BYPASS=false
          - ODYSSEUS_ADMIN_USER=${cfg.adminUser}
          - ODYSSEUS_ADMIN_PASSWORD
          - ALLOWED_ORIGINS=${origins}
          - PUID=''${PUID}
          - PGID=''${PGID}
          - SEARXNG_INSTANCE=
          - CHROMADB_HOST=
          - CHROMADB_PORT=
        restart: unless-stopped
  '';
in
{
  options.services.odysseus = {
    enable = lib.mkEnableOption "Odysseus AI workspace (docker compose, from source)";

    rev = lib.mkOption {
      type = lib.types.str;
      default = "934d23c0be29c9721385f34565c0ae2cbd60da04";
      description = "Pinned upstream revision (github:odysseus-dev/odysseus).";
    };

    hash = lib.mkOption {
      type = lib.types.str;
      default = "sha256-/kGtXHIP9XTMqxK7aP5BotnCKY1Zc9MVUFVd5w0HdMg=";
      description = "Source hash for {option}`rev` (nix-prefetch-git / SRI).";
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address the web UI binds to (e.g. the Tailscale IP).";
    };

    waitForBindAddress = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Before `docker compose up`, wait for {option}`bindAddress` to exist on a
        local interface. Prevents the container from coming up without its port
        mapping when the address (e.g. a Tailscale IP) isn't ready at boot.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 7000;
      description = "Host port for the web UI.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Open {option}`port`. Harmless when {option}`bindAddress` is a tailnet
        address (nothing listens on the LAN), and required if it is not.
      '';
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/odysseus";
      description = "State/log directory bind-mounted into the container.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "odysseus";
      description = "System user owning {option}`dataDir` and used as the container PUID/PGID.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "odysseus";
      description = "System group for {option}`user`.";
    };

    llmHost = lib.mkOption {
      type = lib.types.str;
      default = "host.docker.internal";
      description = "LLM host the container scans; the default reaches the Docker host (LiteLLM).";
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        EnvironmentFile with `LITELLM_MASTER_KEY=...`, exported to the
        container as `OPENAI_API_KEY`. Point at an agenix secret.
      '';
    };

    authEnabled = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Require login for the web UI.";
    };

    adminUser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "First admin username.";
    };

    adminPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        EnvironmentFile with `ODYSSEUS_ADMIN_PASSWORD=...`, seeding the first
        admin password. Point at an agenix secret.
      '';
    };

    allowedOrigins = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "http://localhost:7000" ];
      description = "CORS allowed origins for the web UI.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra env vars exported before `docker compose` (available for interpolation).";
    };

    seedEndpoints = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Display name for the endpoint.";
          };
          url = lib.mkOption {
            type = lib.types.str;
            description = "OpenAI-compatible base URL (used as the idempotency key).";
          };
          apiKeyEnv = lib.mkOption {
            type = lib.types.str;
            default = "LITELLM_MASTER_KEY";
            description = ''
              Name of the env var (present in {option}`apiKeyFile`) holding the
              bearer token for this endpoint. Passed into the container by name
              so the secret never reaches the process command line.
            '';
          };
        };
      });
      default = [ ];
      description = ''
        LLM provider endpoints inserted into the app's SQLite DB on start.
        Idempotent by `url`; runs after {option}`enable` brings the container up.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = { };
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
    };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/data 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/logs 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.odysseus = {
      description = "Odysseus AI workspace (docker compose, from source)";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "docker.service" "network-online.target" ];
      requires = [ "docker.service" ];
      environment = cfg.extraEnvironment;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        EnvironmentFile = [ cfg.apiKeyFile cfg.adminPasswordFile ];
        WorkingDirectory = cfg.dataDir;
        ExecStart = upScript;
        ExecStop = downScript;
        # First build compiles the app image from source on a slow CPU; don't
        # let systemd's default 90s start timeout kill it.
        TimeoutStartSec = 3600;
      };
    };

    # Seed endpoints after the app (and its DB schema) is up. Separate unit so a
    # transient probe failure can't take down the workspace itself.
    systemd.services.odysseus-seed = lib.mkIf (cfg.seedEndpoints != [ ]) {
      description = "Seed Odysseus LLM provider endpoints";
      wantedBy = [ "multi-user.target" ];
      after = [ "odysseus.service" ];
      requires = [ "odysseus.service" ];
      environment = cfg.extraEnvironment;
      serviceConfig = {
        Type = "oneshot";
        EnvironmentFile = [ cfg.apiKeyFile ];
        ExecStart = seedScript;
      };
    };

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ cfg.port ];
  };
}
