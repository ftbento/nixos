# odysseus — a self-hosted AI workspace (chat, agents, email, research, notes).
#
# Runs upstream's full multi-service docker compose stack (odysseus + searxng +
# chromadb + ntfy). LiteLLM on the Docker host is the single LLM provider
# (host.docker.internal), aggregating every model target; Odysseus stores the
# direct model names and any failover between them is configured by the user in
# the UI (the app has its own built-in fallback — no proxy-level aliases here).
#
# The app image is built from a pinned upstream source tree on first service
# start (`docker compose up -d --build`). Compose layer-caches, so subsequent
# boots reuse the image unless `rev` changes. Companion services are pinned to
# explicit image tags so an upstream `latest` break can't wedge the stack. The
# web UI binds to a single address (the Tailscale IP keeps it tailnet-only);
# ntfy is likewise bound to the tailnet, searxng/chromadb stay on loopback.

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

  # Upstream's compose is used as-is; this override only adds what we need on
  # top: a stable container name (the seed unit `docker exec`s it), a tagged
  # app image, and pinned companion images. Relative bind mounts in the
  # upstream file (`./config/...`, `./scripts/...`) resolve against the project
  # directory, which is the directory of the first `-f` file — the pinned
  # source tree — so they keep working.
  overrideFile = pkgs.writeText "odysseus-compose.override.yml" ''
    services:
      odysseus:
        container_name: odysseus
        image: odysseus:local
        build:
          context: ${src}
          args:
            INSTALL_OPTIONAL: ${lib.boolToString cfg.buildOptional}
      chromadb:
        image: ${cfg.chromadbImage}
      ntfy:
        image: ${cfg.ntfyImage}
  '';

  composeArgs = "-p odysseus"
    + " -f ${src}/docker-compose.yml"
    + " -f ${overrideFile}";

  # Non-secret compose interpolation vars (fed to the compose process env).
  # Secrets — OPENAI_API_KEY, ODYSSEUS_ADMIN_PASSWORD, SEARXNG_SECRET — arrive
  # via EnvironmentFile instead, so they never land in the Nix store.
  baseEnv = {
    APP_BIND = cfg.bindAddress;
    APP_PORT = toString cfg.port;
    APP_DATA_DIR = "${cfg.dataDir}/data";
    APP_LOGS_DIR = "${cfg.dataDir}/logs";
    LLM_HOST = cfg.llmHost;
    ODYSSEUS_ADMIN_USER = cfg.adminUser;
    AUTH_ENABLED = lib.boolToString cfg.authEnabled;
    ALLOWED_ORIGINS = origins;
    CHROMADB_BIND = cfg.chromadbBind;
    NTFY_BIND = cfg.ntfyBind;
    NTFY_BASE_URL = cfg.ntfyBaseUrl;
    # Cache lives inside the bind-mounted /app/data so fastembed survives a
    # container recreate.
    FASTEMBED_CACHE_PATH = "/app/data/fastembed";
  };

  # Open the ntfy port only when it is bound somewhere other than loopback;
  # the firewall is interface-agnostic, but nothing listens on the LAN when the
  # bind is the tailnet address, so this doesn't widen LAN exposure.
  ntfyBound = !(lib.elem cfg.ntfyBind [ "127.0.0.1" "::1" "" ]);

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
    # The agenix file exposes LITELLM_MASTER_KEY; upstream's compose wants it
    # as OPENAI_API_KEY. Map it here so the secret stays out of the store.
    export OPENAI_API_KEY="''${LITELLM_MASTER_KEY:-}"
    ${lib.optionalString cfg.waitForBindAddress waitForBind}
    exec ${dockerCompose} ${composeArgs} up -d --build --force-recreate
  '';
  downScript = pkgs.writeShellScript "odysseus-down" ''
    exec ${dockerCompose} ${composeArgs} down
  '';

  # Idempotent, by base_url. Runs inside the container (only place with both
  # the app's Fernet key at data/.app_key and the cryptography package), so the
  # API key gets encrypted through the app's own ORM — a raw sqlite insert would
  # store plaintext the app can't read. Also refreshes `cached_models` and
  # `pinned_models` on every start: LiteLLM is an API/proxy endpoint, so the
  # picker's allow-list is `pinned_models` (not the cached inventory), and
  # proxy-kind endpoints don't auto-refresh. Keeping both in sync makes the
  # LiteLLM model_list the single source of truth for what Odysseus exposes.
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
                        ep.pinned_models = json.dumps(models)
                    # LiteLLM aggregates direct models, several of which are
                    # known-good for native tool calls even though their names
                    # (e.g. gpt-oss-20b) are on Odyssesus's internal no-tools
                    # block-list. Flag the whole proxy endpoint as tool-capable.
                    ep.supports_tools = True
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
        Open {option}`port` (and {option}`ntfyPort` when ntfy is bound off
        loopback). Harmless when the bind address is a tailnet address (nothing
        listens on the LAN), and required if it is not.
      '';
    };

    searxngSecretFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        EnvironmentFile with `SEARXNG_SECRET=...`, substituted into SearXNG's
        `settings.yml` by the container entrypoint. Point at an agenix secret.
      '';
    };

    chromadbBind = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host address ChromaDB's port is published on (loopback by default).";
    };

    ntfyBind = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = ''
        Host address ntfy's port is published on. Set to the Tailscale IP for
        phone push over the tailnet.
      '';
    };

    ntfyPort = lib.mkOption {
      type = lib.types.port;
      default = 8091;
      description = "Host port ntfy is published on.";
    };

    ntfyBaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://localhost:8091";
      description = ''
        Public base URL ntfy advertises (set to `http://<tailscale-ip>:<port>`
        when {option}`ntfyBind` is the tailnet address). Only affects the URL
        shown in-topic, not where ntfy listens.
      '';
    };

    chromadbImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/chromadb/chroma:1.5.9";
      description = "Pinned ChromaDB image (avoid an untested `latest`).";
    };

    ntfyImage = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/binwiederhier/ntfy:v2.30.0";
      description = "Pinned ntfy image (avoid an untested `latest`).";
    };

    buildOptional = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Build the app image with upstream's optional dependencies
        (`INSTALL_OPTIONAL`). Off keeps the image slim; turn on only when a
        Cookbook feature needs them.
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
      # Upstream mounts these from under the data dir; create them up front so
      # Docker doesn't create root-owned dirs on first start.
      "d ${cfg.dataDir}/data/ssh 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/data/huggingface 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/data/local 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/data/fastembed 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.odysseus = {
      description = "Odysseus AI workspace (docker compose, from source)";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "docker.service" "network-online.target" ];
      requires = [ "docker.service" ];
      environment = baseEnv // cfg.extraEnvironment;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        EnvironmentFile = [ cfg.apiKeyFile cfg.adminPasswordFile cfg.searxngSecretFile ];
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

    networking.firewall.allowedTCPPorts =
      lib.optional cfg.openFirewall cfg.port
      ++ lib.optional (cfg.openFirewall && ntfyBound) cfg.ntfyPort;
  };
}
