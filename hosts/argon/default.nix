# argon — home server (headless)

{ config, lib, pkgs, inputs, ... }:

let
  # Declarative CouchDB configuration matching the active runtime settings
  couchdbConfig = pkgs.writeText "10-livesync.ini" ''
    [couchdb]
    single_node = true
    max_document_size = 4294967296

    [chttpd]
    bind_address = 0.0.0.0
    port = 5984
    require_valid_user = true
    enable_cors = true
    max_http_request_size = 4294967296

    [chttpd_auth]
    require_valid_user = true
    hash_algorithms = sha256, sha

    [httpd]
    enable_cors = true
    WWW-Authenticate = Basic realm="couchdb"

    [cors]
    credentials = true
              
    origins = https://argon.note-tawny.ts.net,http://localhost,capacitor://localhost,app://obsidian.md
    headers = accept, authorization, content-type, origin, referer
    methods = GET, PUT, POST, HEAD, DELETE
  '';

  # --- Local LLM fallback (CPU, AVX2) ---
  # argon's always-on fallback for LiteLLM when radon is off. Built from
  # pkgs.llama-cpp-avx2 (modules/services/ai/llama-cpp-avx2.nix) so the 3400G
  # gets AVX2/FMA instead of the baseline SSE2 default; -t 4 = physical cores.
  llamaServer = lib.getExe' pkgs.llama-cpp-avx2 "llama-server";
  modelsDir = "/var/lib/llama/models";
in
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/core.nix
    ../../modules/services/ai/llama-cpp-avx2.nix
    ../../modules/services/ai/llama-swap.nix
    ../../modules/services/odysseus
    ../../modules/services/monitoring
    ../../modules/services/dashboard
  ];

  networking.hostName = "argon";
  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking & Static IP Configuration (10.8.90.205 on the LAN NIC).
  networking.useDHCP = false;
  networking.interfaces.enp10s0 = {
    ipv4.addresses = [{
      address = "10.8.90.205";
      prefixLength = 24;
    }];
  };
  networking.defaultGateway = "10.8.90.1";
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

  # --- Swap (6 GB swapfile) ---
  # argon shipped with no swap; a 6 GB file gives the LLM + Odysseus stack
  # headroom. Declared here so it is created/reapplied on every boot.
  swapDevices = [
    { device = "/var/lib/llama/swapfile"; size = 6144; }
  ];

  # --- Local LLM fallback (llama-swap on CPU) ---
  # Loopback-only: LiteLLM runs on this host and proxies here when radon is
  # unreachable, so no firewall opening is needed. Lazy load (ttl 600s) keeps
  # the ~4.6 GB out of RAM while radon is up (the common case).
  services.llamaSwap = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9101;
    extraGroups = [ ]; # CPU-only build: no GPU device nodes required
    settings = {
      healthCheckTimeout = 120;
      logLevel = "info";
      logToStdout = "proxy";
      globalTTL = 600;
      startPort = 10101;
      models."qwen3.5-4b" = {
        name = "Qwen3.5 4B (local fallback)";
        cmd = lib.concatStringsSep " " [
          llamaServer
          "--model ${modelsDir}/Qwen_Qwen3.5-4B-Q4_K_M.gguf"
          "--port \${PORT}"
          "--threads 4"
          "--ctx-size 8192"
          "--jinja"
          # Qwen3.5 defaults to "thinking": unbounded reasoning with empty
          # content, which on a 4B/CPU fallback looks like a hang (and pins the
          # box). Off for the fallback — users want an answer, not a monologue.
          "--reasoning off"
          "--no-webui"
        ];
      };
    };
  };

  # GGUF weights directory, owned by the service user so llama-swap can read.
  systemd.tmpfiles.rules = [
    "d /var/lib/llama/models 0750 llama-swap llama-swap -"
  ];

  # --- LiteLLM (model aggregator) ------------------------------------------
  # One OpenAI-compatible endpoint that gathers every model target under its
  # real upstream name — no aliases, no proxy-level failover. Odysseus points
  # here for all models; any failover between them is configured by the user in
  # Odysseus's own UI. Background health checks are left off on the argon row:
  # they would load the lazy local 4B model and immediately unload it again (the
  # per-deployment disable flag also keeps on-demand /health cheap).
  services.litellm = {
    enable = true;
    host = "0.0.0.0"; # Odysseus runs in Docker and must reach the host
    port = 4000;
    environmentFile = config.age.secrets.litellm-master-key.path;
    settings = {
      model_list = [
        # --- radon (Vulkan GPU) ---
        {
          model_name = "gpt-oss-20b";
          litellm_params = { model = "openai/gpt-oss-20b"; api_base = "http://10.8.90.228:9100/v1"; api_key = "sk-no-key"; };
          model_info = { id = "gpt-oss-20b-radon"; };
        }
        {
          model_name = "qwen3.6-35b-a3b";
          litellm_params = { model = "openai/qwen3.6-35b-a3b"; api_base = "http://10.8.90.228:9100/v1"; api_key = "sk-no-key"; };
          model_info = { id = "qwen3.6-35b-a3b-radon"; };
        }
        # 9B stands in for the real Ajax model; swap this line when it lands.
        {
          model_name = "qwen3.5-9b";
          litellm_params = { model = "openai/qwen3.5-9b"; api_base = "http://10.8.90.228:9100/v1"; api_key = "sk-no-key"; };
          model_info = { id = "qwen3.5-9b-radon"; };
        }
        # --- argon (CPU) ---
        # Exposed under its real name so it can be wired as a fallback target
        # for any radon model in Odysseus's per-user fallback UI.
        {
          model_name = "qwen3.5-4b";
          litellm_params = { model = "openai/qwen3.5-4b"; api_base = "http://127.0.0.1:9101/v1"; api_key = "sk-no-key"; };
          model_info = { id = "qwen3.5-4b-argon"; disable_background_health_check = true; };
        }
      ];
      general_settings = {
        master_key = "os.environ/LITELLM_MASTER_KEY";
      };
      litellm_settings = {
        drop_params = true;     # llama-server rejects unknown OpenAI params
        request_timeout = 600;  # allow for a cold model load on radon
      };
      # Each model is a single deployment, so there is nothing to fail over to
      # at this layer (order/cooldown would be inert). Odysseus owns fallback.
      router_settings = {
        num_retries = 0;
      };
    };
  };

  # --- Odysseus (self-hosted AI workspace) ---
  # Full upstream stack (odysseus + searxng + chromadb + ntfy), built from a
  # pinned upstream rev. The UI is bound to the Tailscale IP so it never lands
  # on the LAN; ntfy is likewise tailnet-only, while searxng/chromadb stay on
  # loopback. Its LLM provider points at LiteLLM on the host
  # (host.docker.internal:4000) using the master key; all model targets are
  # direct names and any fallback is configured in Odysseus itself.
  services.odysseus = {
    enable = true;
    bindAddress = "100.97.118.91"; # tailnet-only
    allowedOrigins = [
      "http://100.97.118.91:7000"
      "http://argon.note-tawny.ts.net:7000"
    ];
    apiKeyFile = config.age.secrets.litellm-master-key.path;
    adminPasswordFile = config.age.secrets.odysseus-admin-password.path;
    searxngSecretFile = config.age.secrets.searxng-secret.path;
    # ntfy over the tailnet so phones can subscribe without LAN exposure.
    ntfyBind = "100.97.118.91";
    ntfyBaseUrl = "http://100.97.118.91:8091";
    # Seed the LiteLLM proxy as an LLM provider (avoids the manual Settings
    # dance; endpoint discovery can't find :4000 on its own).
    seedEndpoints = [
      {
        name = "LiteLLM";
        url = "http://host.docker.internal:4000/v1";
      }
    ];
  };

  programs.git = {
    enable = true;
    config = {
      user = {
        name = "ftbento";
        email = "ftbento@users.noreply.github.com";
      };
    };
  };

  # Agenix Secrets Management
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  age.secrets = {
    couchdb-env = {
      file = ../../secrets/couchdb-env.age;
      mode = "0400";
    };
    github-ftbento = {
      file = ../../secrets/github-ftbento.age;
      owner = "root";
    };
    litellm-master-key = {
      # `LITELLM_MASTER_KEY=sk-...` — the proxy's own API key. Read by systemd
      # as root via the litellm unit's EnvironmentFile, so root/0400 is fine
      # even though the service itself runs as a DynamicUser.
      file = ../../secrets/litellm-master-key.age;
      owner = "root";
      mode = "0400";
    };
    odysseus-admin-password = {
      # `ODYSSEUS_ADMIN_PASSWORD=...` — seeds the first Odysseus admin login.
      # Read by systemd (root) as the odysseus unit's EnvironmentFile.
      file = ../../secrets/odysseus-admin-password.age;
      owner = "root";
      mode = "0400";
    };
    searxng-secret = {
      # `SEARXNG_SECRET=...` — substituted into SearXNG's settings.yml by the
      # container entrypoint. Read by systemd (root) as the odysseus unit's
      # EnvironmentFile and interpolated into the compose environment.
      file = ../../secrets/searxng-secret.age;
      owner = "root";
      mode = "0400";
    };
  };

  # Use the agenix-decrypted GitHub key for git pulls (and git protocol over ssh)
  programs.ssh.extraConfig = ''
    Host github.com
      IdentityFile ${config.age.secrets."github-ftbento".path}
      IdentitiesOnly yes
  '';

  # Authorized Keys for Remote Access
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGESGigvG8ZWWQIv5S+Kg7ECkbwFxSoBIX29tNh/BmZu benjidev@radon"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB4kXVbiNiirKZkljHnD+t15Hd9iTocub0TbKU8s8m00 benjidev@Ben-Elitebook"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINMljzW9ywXfHTz63oOtGh/ovwwa5RX8gXzf0ftE7f/3 3a@nothing"
  ];

  # --- Remote SSH server ---
  services.openssh = {
    enable = true;
    ports = [ 205 ];
    settings.PermitRootLogin = "prohibit-password";
  };

  # --- Firewall ---
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      205    # SSH
      5984   # Obsidian LiveSync
    # 80 is opened by services/dashboard (nginx + the port option).
    ];
    allowedUDPPorts = [
      41641  # Tailscale
    ];

    # LiteLLM (:4000) — listens on 0.0.0.0 so both the LAN and the Docker
    # bridge can reach it (Odysseus runs in a container and talks to the host).
    # nixos-fw already accepts loopback; the rest is source-restricted.
    extraCommands = ''
      iptables -A nixos-fw -p tcp -s 10.8.90.0/24 --dport 4000 -j nixos-fw-accept
      iptables -A nixos-fw -p tcp -s 172.16.0.0/12 --dport 4000 -j nixos-fw-accept
    '';
    extraStopCommands = ''
      iptables -D nixos-fw -p tcp -s 10.8.90.0/24 --dport 4000 -j nixos-fw-accept 2>/dev/null || true
      iptables -D nixos-fw -p tcp -s 172.16.0.0/12 --dport 4000 -j nixos-fw-accept 2>/dev/null || true
    '';
  };

  # --- Container engine ---
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # --- Declarative OCI containers ---
  virtualisation.oci-containers.backend = "docker";

  # --- Monitoring hub (Prometheus + Grafana) ---
  # argon runs the server facet and its own agent. Future servers just enable
  # the exporter and add their MagicDNS name to server.targets.
  services.monitoring = {
    exporter = {
      enable = true;
      containerMetrics = true; # CouchDB container stats via cAdvisor
    };
    server.enable = true;
    # Phone push alerts: container/host health, load/memory/disk, plus a
    # boot notification that fires when argon comes back after a crash.
    server.alerting = {
      enable = true;
      ntfyTopic = "nixos-argon-alerts";
      containers = [ "obsidian-livesync" ];
    };
  };

  # --- Services dashboard ---
  # Homepage UI behind nginx on :80: clickable cards for every service on this
  # box. Web UIs open directly; non-web services (SSH, CouchDB, Tailscale) open
  # a generated /info/<slug> page explaining how to use them.
  services.dashboard = {
    enable = true;
    # Homepage checks the Host header, so every name/IP used to reach the
    # dashboard must be allowed (nginx preserves it on the way through).
    allowedHosts = [ "argon.note-tawny.ts.net" "10.8.90.205" ];
    services = [
      # --- Web UIs ---
      {
        group = "Web UI";
        name = "Grafana";
        description = "Prometheus metrics dashboards";
        icon = "si-grafana";
        href = "http://argon.note-tawny.ts.net:3000";
        siteMonitor = "http://argon.note-tawny.ts.net:3000";
      }
      # --- No web UI: docs pages under /info/<slug> ---
      {
        group = "Access & Infrastructure";
        name = "SSH";
        description = "Remote shell root@argon, port 205";
        icon = "mdi-console-line";
        ping = "argon.note-tawny.ts.net";
        info = ''
          Connect via SSH on port 205 (the default 22 is closed):

            ssh root@argon -p 205

          Key-based auth only. Public keys are managed declaratively in
          hosts/argon/default.nix (users.users.root.openssh.authorizedKeys)
          and deployed with a rebuild, so no password prompt and no known-hosts
          surprises.

          Tunneling also works, e.g. forward a service to your machine:

            ssh -L 3000:localhost:3000 root@argon -p 205

          As a NixOS system, config is applied with:

            sudo nixos-rebuild switch --flake .#argon
        '';
      }
      {
        group = "Access & Infrastructure";
        name = "Obsidian LiveSync";
        description = "CouchDB sync backend on port 5984";
        icon = "si-couchdb";
        ping = "argon.note-tawny.ts.net";
        info = ''
          "Self-hosted LiveSync" (community plugin) syncs vaults through the
          CouchDB container listening on 5984. In Obsidian, set:

            Remote database type: CouchDB
            URI: https://argon.note-tawny.ts.net
            (same-LAN fallback: http://10.8.90.205:5984)
            Username / password: from the couchdb-env agenix secret

          Read the credentials with:

            cd ~/nixos/secrets && agenix -d couchdb-env.age

          CORS already allows argon.note-tawny.ts.net, localhost and Obsidian
          (app://obsidian.md). Documents up to 4 GB are accepted (see the
          max_document_size setting in hosts/argon/default.nix).
        '';
      }
      {
        group = "Access & Infrastructure";
        name = "Tailscale";
        description = "Tailnet: argon.note-tawny.ts.net / 100.97.118.91";
        icon = "si-tailscale";
        ping = "argon.note-tawny.ts.net";
        info = ''
          argon is reachable on the tailnet as argon.note-tawny.ts.net
          (tailnet IP 100.97.118.91). Useful from any node:

            tailscale status              # list machines
            tailscale ping argon          # check reachability
            ssh root@argon -p 205         # SSH over the tailnet

          This dashboard (:80) and Grafana (:3000) are accessible over the
          tailnet without exposing extra ports publicly.
        '';
      }
      # --- AI stack ---
      {
        group = "AI";
        name = "Odysseus";
        description = "Self-hosted AI workspace (tailnet-only)";
        icon = "mdi-robot";
        href = "http://argon.note-tawny.ts.net:7000";
        siteMonitor = "http://100.97.118.91:7000";
      }
      {
        group = "AI";
        name = "LiteLLM";
        description = "Aggregated OpenAI-compatible model endpoint";
        icon = "mdi-brain";
        siteMonitor = "http://127.0.0.1:4000/health/liveliness";
        info = ''
          LiteLLM is the OpenAI-compatible proxy every client should talk to.
          Every model target is exposed under its real upstream name — no
          aliases and no proxy-level failover. Fallback between models is
          configured in Odysseus's own UI.

            gpt-oss-20b      -> GPT-OSS 20B (radon GPU)
            qwen3.6-35b-a3b  -> Qwen3.6 35B-A3B (radon GPU)
            qwen3.5-9b       -> Qwen3.5 9B (radon GPU; Ajax stand-in)
            qwen3.5-4b       -> Qwen3.5 4B (argon CPU; fallback target)

          Endpoint: http://10.8.90.205:4000/v1 (LAN only; :4000 is not
          reachable over the tailnet). Authenticate with the master key:

            cd ~/nixos/secrets && agenix -d litellm-master-key.age

          Quick check:

            curl -s http://10.8.90.205:4000/v1/models \
              -H "Authorization: Bearer $LITELLM_MASTER_KEY"

          Odysseus already points here; any other OpenAI-compatible client
          (Continue, aider, ...) can too.
        '';
      }
      {
        group = "AI";
        name = "SearXNG";
        description = "Private web search + Deep Research backend";
        icon = "mdi-magnify";
        siteMonitor = "http://127.0.0.1:8080/";
        info = ''
          SearXNG backs Odysseus web search and Deep Research. It listens on
          loopback (127.0.0.1:8080) and is reached in-network as
          http://searxng:8080; it is not exposed on the LAN or tailnet.

          The instance secret is replaced into settings.yml on first boot from
          the searxng-secret agenix secret.
        '';
      }
      {
        group = "AI";
        name = "ChromaDB";
        description = "Vector store for Odysseus memory/RAG";
        icon = "mdi-database";
        siteMonitor = "http://127.0.0.1:8100/api/v2/heartbeat";
        info = ''
          ChromaDB stores Odysseus embeddings for memory and retrieval.
          Loopback-only (127.0.0.1:8100); reached in-network as
          http://chromadb:8000. Data lives in the `odysseus_chromadb-data`
          Docker volume.

          Embeddings are generated locally with fastembed (no external API).
        '';
      }
      {
        group = "AI";
        name = "ntfy";
        description = "Push notifications (tailnet-only)";
        icon = "mdi-bell";
        siteMonitor = "http://100.97.118.91:8091/v1/health";
        info = ''
          ntfy delivers push notifications to phones/browsers. It is bound to
          the tailnet at http://100.97.118.91:8091 (no auth — tailnet members
          only).

          Subscribe in the ntfy app to a topic, e.g.:

            http://100.97.118.91:8091/odysseus

          Odysseus's notification integration points at the in-network name
          http://ntfy:80.
        '';
      }
    ];
  };

  system.activationScripts.obsidian-couchdb.text = ''
    mkdir -p /var/lib/obsidian-livesync
    cp -f ${couchdbConfig} /var/lib/obsidian-livesync/10-livesync.ini
  '';
  # CouchDB admin credentials, sourced from the agenix secret. CouchDB only
  # applies COUCHDB_USER/COUCHDB_PASSWORD env vars on first boot, so instead we
  # generate an `[admins]` ini fragment that CouchDB re-reads (and re-hashes)
  # at every start. Rotating the password = edit the secret + rebuild; the
  # container is restarted here when the file changes.
  system.activationScripts.obsidian-couchdb-admins = lib.stringAfter [ "agenixInstall" ] ''
    mkdir -p /var/lib/obsidian-livesync
    user=$(${lib.getExe pkgs.gnused} -n 's/^COUCHDB_USER=//p' ${config.age.secrets.couchdb-env.path})
    pass=$(${lib.getExe pkgs.gnused} -n 's/^COUCHDB_PASSWORD=//p' ${config.age.secrets.couchdb-env.path})
    admins=/var/lib/obsidian-livesync/10-admins.ini
    {
      echo "[admins]"
      echo "$user = $pass"
    } > "$admins.new"
    chown 5984:5984 "$admins.new"
    chmod 600 "$admins.new"
    systemctl=${config.systemd.package}/bin/systemctl
    if [ ! -f "$admins" ] || ! ${pkgs.diffutils}/bin/cmp -s "$admins" "$admins.new"; then
      mv "$admins.new" "$admins"
      "$systemctl" reset-failed docker-obsidian-livesync.service 2>/dev/null || true
      "$systemctl" restart docker-obsidian-livesync.service 2>/dev/null || true
    else
      rm -f "$admins.new"
    fi
  '';
  virtualisation.oci-containers.containers = {
    obsidian-livesync = {
      image = "couchdb:3.3.3";
      ports = [ "5984:5984" ];
      volumes = [
        "/var/lib/obsidian-livesync:/opt/couchdb/data"
        "/var/lib/obsidian-livesync/10-livesync.ini:/opt/couchdb/etc/local.d/10-livesync.ini"
        # Admin credentials (generated from the secret at activation) — CouchDB
        # loads local.d ini fragments on every start, unlike env vars which are
        # only honoured on first boot.
        "/var/lib/obsidian-livesync/10-admins.ini:/opt/couchdb/etc/local.d/10-admins.ini"
      ];
    };
  };
}
