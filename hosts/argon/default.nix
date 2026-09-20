# argon — home server (headless)

{ config, pkgs, inputs, ... }:

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
    ];
  };

  rackpeekYaml = (pkgs.formats.yaml {}).generate "config.yaml" rackpeekSpec;
in
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/core.nix
  ];

  networking.hostName = "argon";
  system.stateVersion = "26.05";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking & Static IP Configuration
  networking.useDHCP = false;
  networking.interfaces.enp10s0 = {
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
  system.activationScripts.obsidian-couchdb.text = ''
    mkdir -p /var/lib/obsidian-livesync
    cp -f ${couchdbConfig} /var/lib/obsidian-livesync/10-livesync.ini
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
      environmentFiles = [
        config.age.secrets.couchdb-env.path
      ];
      volumes = [
        "/var/lib/obsidian-livesync:/opt/couchdb/data"
        "/var/lib/obsidian-livesync/10-livesync.ini:/opt/couchdb/etc/local.d/10-livesync.ini"
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
