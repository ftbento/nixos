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

in
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/core.nix
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

  # Swap removed along with the LLM stack (was /var/lib/llama/swapfile).

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
      3001   # Uptime Kuma
    # 80 is opened by services/dashboard (nginx + the port option).
    ];
    allowedUDPPorts = [
      41641  # Tailscale
    ];

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

  # --- Uptime Kuma (simple up/down checks + status page) ---
  # Complements the Grafana/Prometheus stack: external "is it up?" checks,
  # public status page, SSL expiry, 90+ notification channels. Native module
  # (DynamicUser, SQLite state in /var/lib/uptime-kuma).
  services.uptime-kuma = {
    enable = true;
    settings = {
      HOST = "0.0.0.0";
      PORT = "3001";
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
      {
        group = "Web UI";
        name = "Uptime Kuma";
        description = "Uptime monitoring + status page";
        icon = "si-uptimekuma";
        href = "http://argon.note-tawny.ts.net:3001";
        siteMonitor = "http://argon.note-tawny.ts.net:3001";
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
