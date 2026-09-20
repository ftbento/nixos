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

  # Declarative RackPeek inventory documenting this server and its services.
  # Schema v2: https://raw.githubusercontent.com/Timmoth/RackPeek/main/schemas/v2/schema.v2.json
  # Hardware facts captured from the live host (Ryzen 5 3400G, ~10 GB RAM,
  # 256 GB NVMe, Gigabit NIC). Nix is the source of truth — this YAML is
  # regenerated on every rebuild and not edited through the web UI.
  rackpeekSpec = {
    version = 2;
    resources = [
      {
        kind = "Server";
        name = "argon";
        tags = [ "home-server" "nixos" ];
        notes = "Headless home server running NixOS.";
        labels = {
          hostname = "argon";
          ip = "10.8.90.205";
        };
        ram = { size = 10; };
        cpus = [
          {
            model = "AMD Ryzen 5 3400G with Radeon Vega Graphics";
            cores = 4;
            threads = 8;
          }
        ];
        drives = [ { type = "nvme"; size = 256; } ];
        nics = [ { type = "rj45"; speed = 1000; ports = 1; } ];
      }
      {
        kind = "System";
        name = "nixos";
        runsOn = [ "argon" ];
        type = "baremetal";
        os = "NixOS 26.05 (Yarara), kernel 6.18.46";
        cores = 8;
        ram = 10;
        drives = [ { type = "nvme"; size = 256; } ];
      }
      {
        kind = "System";
        name = "proxmox-ve";
        tags = [ "proxmox" "virtualization" ];
        notes = "Native Proxmox VE hypervisor running on NixOS (proxmox-nixos), pve-manager 9.2.";
        runsOn = [ "argon" ];
        type = "hypervisor";
        os = "Proxmox VE 9.2 (pve-manager) on NixOS 26.05";
        cores = 8;
        ram = 10;
        drives = [ { type = "nvme"; size = 256; } ];
      }
      {
        kind = "Service";
        name = "openssh";
        runsOn = [ "argon" ];
        network = {
          ip = "10.8.90.205";
          port = 205;
          protocol = "TCP";
        };
      }
      {
        kind = "Service";
        name = "obsidian-livesync";
        notes = "CouchDB 3.3.3 container serving Obsidian LiveSync.";
        runsOn = [ "argon" ];
        network = {
          ip = "10.8.90.205";
          port = 5984;
          protocol = "TCP";
          url = "https://argon.note-tawny.ts.net";
        };
      }
      {
        kind = "Service";
        name = "tailscale";
        runsOn = [ "argon" ];
        network = {
          ip = "10.8.90.205";
          port = 41641;
          protocol = "UDP";
        };
      }
      {
        kind = "Service";
        name = "rackpeek";
        notes = "Homelab documentation web UI backed by this declarative YAML.";
        runsOn = [ "argon" ];
        network = {
          ip = "10.8.90.205";
          port = 8080;
          protocol = "TCP";
          url = "http://argon.note-tawny.ts.net:8080";
        };
      }
      {
        kind = "Service";
        name = "proxmox-ve";
        notes = ''
          Web UI + REST API of the native PVE stack (proxmox-nixos on NixOS),
          listening on :8006.

          ## Monitoring the hypervisor

          The monitoring hub scrapes PVE through prometheus-pve-exporter
          (Prometheus job `pve`, localhost:9221, every 60s) and provisions a
          "Proxmox VE" Grafana dashboard. The exporter authenticates with an API
          token bound to a dedicated user, never with root@pam.

          ### RBAC — set up once in the web UI (https://10.8.90.205:8006)

          1. Datacenter → Permissions → Users → Add
             - User: `monitoring`, Realm: `Proxmox VE authentication server` (PVE)
             - Password can be anything; the API token below is what is used.
          2. Datacenter → Permissions → Roles → Add: role `Monitoring` with
             privileges `Sys.Audit`, `VM.Audit`, `Datastore.Audit`
             (`Pool.Audit` too if pools are used).
             - `PVEAuditor` is NOT enough: the exporter needs `Sys.Audit` on `/`
               (403 "Permission check failed (/, Sys.Audit)" otherwise).
          3. Datacenter → Permissions → Add: assign user `monitoring@pve` the
             role `Monitoring` at Path `/`.
          4. Datacenter → Permissions → API Tokens → Add
             - User: `monitoring@pve`, TokenID: `monitoring`
             - Leave *Privilege Separation* unchecked so the token inherits the
               `Monitoring` role.

          ### Token lifecycle (agenix, never in the repo in clear text)

          Sealed in `secrets/proxmox-pve-exporter.age` (recipients: argon,
          radon, elitebook) as KEY=VALUE lines:

              PVE_USER=monitoring@pve
              PVE_TOKEN_NAME=monitoring
              PVE_TOKEN_VALUE=<token>

          `services.proxmox.pveToken` points the module
          (modules/services/proxmox) at that secret; an activation script
          regenerates `/var/lib/prometheus-pve-exporter/pve.yml` from it on
          every build. To rotate:

          1. Re-seal the secret on radon with the new token value.
          2. `nixos-rebuild switch --flake .#argon --target-host argon`
          3. `systemctl restart prometheus-pve-exporter` (the exporter loads
             pve.yml at start).

          ### Verify

          - `curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:9221/pve?cluster=1&module=default&node=1&target=127.0.0.1"` → 200
          - Prometheus (`http://127.0.0.1:9090/targets`): job `pve` health "up",
            empty lastError; mirrored in the Grafana Proxmox dashboard.
        '';
        runsOn = [ "argon" ];
        network = {
          ip = "10.8.90.205";
          port = 8006;
          protocol = "TCP";
          url = "https://10.8.90.205:8006";
        };
      }
      {
        kind = "Service";
        name = "dashboard";
        notes = "Homepage service landing page behind nginx on :80 (web UIs + /info docs for non-web services).";
        runsOn = [ "argon" ];
        network = {
          ip = "10.8.90.205";
          port = 80;
          protocol = "TCP";
          url = "http://argon.note-tawny.ts.net";
        };
      }
    ];
  };

  rackpeekYaml = (pkgs.formats.yaml {}).generate "config.yaml" rackpeekSpec;
in
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/core.nix
    ../../modules/services/monitoring
    ../../modules/services/proxmox
    ../../modules/services/dashboard
  ];

  networking.hostName = "argon";
  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # KVM acceleration for Proxmox guests (PVE uses its own pve-qemu).
  boot.kernelModules = [ "kvm-amd" ];

  # Networking & Static IP Configuration.
  # The static IP lives on the vmbr0 bridge so Proxmox VMs can share the LAN
  # NIC (enp10s0 becomes a bridge slave). Kept the same 10.8.90.205 address.
  networking.useDHCP = false;
  networking.bridges.vmbr0.interfaces = [ "enp10s0" ];
  networking.interfaces.vmbr0 = {
    ipv4.addresses = [{
      address = "10.8.90.205";
      prefixLength = 24;
    }];
  };
  networking.defaultGateway = "10.8.90.1";
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

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
      8080   # RackPeek (LAN + tailnet)
    # 80 is opened by services/dashboard (nginx + the port option).
    ];
    allowedUDPPorts = [
      41641  # Tailscale
    ];
    # Proxmox (8006 web UI + API, 80/443/111 + corosync UDP 5405-5412) is
    # opened by the proxmox module (services.proxmox-ve.openFirewall).
  };

  # --- Proxmox VE (native hypervisor, via proxmox-nixos) ---
  services.proxmox = {
    enable = true;
    ipAddress = "10.8.90.205";
    bridges = [ "vmbr0" ];
    monitoring = true; # pve exporter -> Prometheus + Grafana dashboard
    pveToken = ../../secrets/proxmox-pve-exporter.age; # PVE API token (agenix)
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
      containerMetrics = true; # CouchDB + RackPeek container stats via cAdvisor
    };
    server.enable = true;
    # Phone push alerts: container/PVE/host health, load/memory/disk, plus a
    # boot notification that fires when argon comes back after a crash.
    server.alerting = {
      enable = true;
      ntfyTopic = "nixos-argon-alerts";
      containers = [ "obsidian-livesync" "rackpeek" ];
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
        name = "RackPeek";
        description = "Homelab inventory & docs";
        icon = "mdi-server";
        href = "http://argon.note-tawny.ts.net:8080";
        siteMonitor = "http://argon.note-tawny.ts.net:8080";
      }
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
        name = "Proxmox VE";
        description = "Virtualization console & API";
        icon = "si-proxmox";
        href = "https://10.8.90.205:8006";
        # Self-signed cert breaks HTTP HEAD checks, so show reachability only.
        ping = "10.8.90.205";
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
        description = "Tailnet: argon.note-tawny.ts.net / 10.8.90.205";
        icon = "si-tailscale";
        ping = "argon.note-tawny.ts.net";
        info = ''
          argon is reachable on the tailnet as argon.note-tawny.ts.net
          (tailnet IP 10.8.90.205). Useful from any node:

            tailscale status              # list machines
            tailscale ping argon          # check reachability
            ssh root@argon -p 205         # SSH over the tailnet

          Docker services (RackPeek :8080, this dashboard :80) are accessible
          over the tailnet without exposing extra ports publicly.
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
  # Declarative RackPeek state: overwritten every rebuild so the docs always
  # match the NixOS config (Nix is the source of truth, not the web UI).
  system.activationScripts.rackpeek.text = ''
    mkdir -p /var/lib/rackpeek
    cp -f ${rackpeekYaml} /var/lib/rackpeek/config.yaml
    # RackPeek runs as UID 1654 (app) and rewrites config.yaml (keeping a .bak),
    # so the state dir + file must be owned by that UID.
    chown -R 1654:1654 /var/lib/rackpeek
    chmod 0660 /var/lib/rackpeek/config.yaml
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
    rackpeek = {
      image = "aptacode/rackpeek:v2.0.0";
      ports = [ "8080:8080" ];
      volumes = [
        "/var/lib/rackpeek:/app/config"
      ];
    };
  };
}
