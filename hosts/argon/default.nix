{ config, pkgs, inputs, ... }:

let
  # Declarative CouchDB configuration matching your active runtime settings
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

    [cors]
    credentials = true
    origins = https://argon.note-tawny.ts.net, http://localhost, capacitor://localhost, app://obsidian.md
    headers = accept, authorization, content-type, origin, referer
    methods = GET, PUT, POST, HEAD, DELETE
  '';
in
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/agenix.nix
  ];

  networking.hostName = "argon";
  system.stateVersion = "26.05";
  time.timeZone = "America/New_York";

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
#    userName = "ftbento";
#    userEmail = "ftbento@users.noreply.github.com";
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
    github-ftbento = {
      file = ../../secrets/github-ftbento.age;
      mode = "0400";
    };
    couchdb-env = {
      file = ../../secrets/couchdb-env.age;
      mode = "0400";
    };
  };

  # Firewall Configuration
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 
      205    # SSH
      5984   # Obsidian LiveSync
    ];
    allowedUDPPorts = [ 
      41641  # Tailscale
    ];
  };

  # Native System Services
  services.openssh = {
    enable = true;
    ports = [ 205 ];
    settings.PermitRootLogin = "prohibit-password";
  };

  # Authorized Keys for Remote Access
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGESGigvG8ZWWQIv5S+Kg7ECkbwFxSoBIX29tNh/BmZu benjidev@radon"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB4kXVbiNiirKZkljHnD+t15Hd9iTocub0TbKU8s8m00 benjidev@Ben-Elitebook"
  ];

  services.tailscale.enable = true;

  # Container Engine
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

  # Declarative OCI Containers
#  virtualisation.oci-containers.backend = "docker";
#  virtualisation.oci-containers.containers = {
#    obsidian-livesync = {
#      image = "couchdb:3.3.3";
#      ports = [ "5984:5984" ];
#      environmentFiles = [
#        config.age.secrets.couchdb-env.path
#      ];
#      volumes = [
#        "/var/lib/obsidian-livesync:/opt/couchdb/data"
#        "${couchdbConfig}:/opt/couchdb/etc/local.d/10-livesync.ini:ro"
#      ];
#    };
#  };

  # Automated Database Provisioning
#  systemd.services.init-couchdb-livesync = {
#    description = "Initialize CouchDB system DBs and databases";
#    after = [ "docker-obsidian-livesync.service" ];
#    wantedBy = [ "multi-user.target" ];
#    script = ''
#      source ${config.age.secrets.couchdb-env.path}
#
#      until ${pkgs.curl}/bin/curl -s http://127.0.0.1:5984/_up | ${pkgs.gnugrep}/bin/grep -q '"status":"ok"'; do
#        sleep 2
#      done

#      ${pkgs.curl}/bin/curl -X PUT http://$COUCHDB_USER:$COUCHDB_PASSWORD@127.0.0.1:5984/_users
#      ${pkgs.curl}/bin/curl -X PUT http://$COUCHDB_USER:$COUCHDB_PASSWORD@127.0.0.1:5984/_replicator
#      ${pkgs.curl}/bin/curl -X PUT http://$COUCHDB_USER:$COUCHDB_PASSWORD@127.0.0.1:5984/_global_changes
#      ${pkgs.curl}/bin/curl -X PUT http://$COUCHDB_USER:$COUCHDB_PASSWORD@127.0.0.1:5984/thorium
#      ${pkgs.curl}/bin/curl -X PUT http://$COUCHDB_USER:$COUCHDB_PASSWORD@127.0.0.1:5984/mikayla
#    '';
#    serviceConfig = {
#      Type = "oneshot";
#      RemainAfterExit = true;
#    };
#  };
}
