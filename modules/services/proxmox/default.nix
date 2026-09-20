# Native Proxmox VE hypervisor on top of NixOS (proxmox-nixos).
#
# Argon keeps being a NixOS system (docker, rackpeek, monitoring hub) and
# additionally runs the real PVE stack (pve-manager + pve-qemu, web UI on
# :8006) built from the `SaumonNet/proxmox-nixos` flake. The module wires:
#
#   overlay            — the proxmox-ve / pve-* package set
#   services.proxmox-ve — cluster filesystem, daemons, API/web proxy
#   binaries cache     — https://cache.saumon.network/proxmox-nixos to avoid
#                        rebuilding the huge pve-qemu from source
#   PVE directory storage — /var/lib/vz (default "local" storage on root ext4)
#
# The `monitoring` facet plugs the Proxmox VE API into the monitoring hub via
# the prometheus-pve-exporter NixOS module and provisions a dashboard. The
# exporter hits the API with an API token (user `monitoring@pve`).
#
# The token is managed declaratively: set `services.proxmox.pveToken` to an
# agenix-encrypted file (PVE_USER / PVE_TOKEN_NAME / PVE_TOKEN_VALUE lines)
# and pve.yml is regenerated from it on every activation. Without a secret,
# a placeholder pve.yml is created once and the token must be pasted in by
# hand (kept out of the nix store).
#
# The token's role needs at least `Sys.Audit` on `/` for the exporter's
# collector (plus VM.Audit / Datastore.Audit for VM/filesystem metrics). A
# token that can log in but lacks `Sys.Audit` fails with
# "403 Permission check failed (/, Sys.Audit)".

{ config, lib, pkgs, inputs, ... }:

let
  cfg = config.services.proxmox;
  exporterPort = 9221;
in
{
  options.services.proxmox = {
    enable = lib.mkEnableOption "Proxmox VE on top of NixOS (proxmox-nixos)";

    ipAddress = lib.mkOption {
      type = lib.types.str;
      description = "IP address of this Proxmox node (also used for /etc/hosts)";
    };

    bridges = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Linux bridges exposed to the Proxmox web UI. The OS-level bridge must
        be created with `networking.bridges` on the host file.
      '';
    };

    monitoring = lib.mkEnableOption ''
      scrape Proxmox VE metrics into the monitoring hub (pve exporter +
      Prometheus job + Grafana dashboard). Only meaningful where
      `services.monitoring.server.enable` is set.
    '';

    pveToken = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to an agenix-encrypted secret holding the PVE API token as
        KEY=VALUE lines:

          PVE_USER=monitoring@pve
          PVE_TOKEN_NAME=monitoring
          PVE_TOKEN_VALUE=<api-token>

        When set (with `monitoring`), the exporter config
        /var/lib/prometheus-pve-exporter/pve.yml is generated from it on every
        activation, so rotating the token means editing the secret and
        rebuilding — no hand-editing on the host. Requires the agenix NixOS
        module to be imported.
      '';
    };
  };

  imports = [
    inputs.proxmox-nixos.nixosModules.proxmox-ve
  ];

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      nixpkgs.overlays = [
        inputs.proxmox-nixos.overlays.x86_64-linux
      ];

      services.proxmox-ve = {
        enable = true;
        ipAddress = cfg.ipAddress;
        bridges = cfg.bridges;
      };

      # VM images / ISOs / dumps live on the root ext4 via the default
      # "local" dir storage under /var/lib/vz.
      system.activationScripts.proxmox-storage.text = ''
        mkdir -p /var/lib/vz/dump /var/lib/vz/images /var/lib/vz/iso /var/lib/vz/template
      '';

      nix.settings = {
        substituters = [ "https://cache.saumon.network/proxmox-nixos" ];
        trusted-public-keys = [ "proxmox-nixos:D9RYSWpQQC/msZUWphOY2I5RLH5Dd6yQcaHIuug7dWM=" ];
      };
    }

    # --- Monitoring facet (Prometheus PVE exporter) ---
    (lib.mkIf cfg.monitoring {
      services.prometheus.exporters.pve = {
        enable = true;
        # Local-only: Prometheus on this host scrapes localhost:9221.
        listenAddress = "127.0.0.1";
        # Mutable file (token lives out of the store): created on activation
        # and edited by hand after creating the `monitoring@pve` API token.
        configFile = "/var/lib/prometheus-pve-exporter/pve.yml";
      };

      services.monitoring.server.extraScrapeConfigs = [
        {
          job_name = "pve";
          scrape_interval = "60s";
          metrics_path = "/pve";
          params = {
            module = [ "default" ];
            cluster = [ "1" ];
            node = [ "1" ];
            target = [ "127.0.0.1" ];
          };
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString exporterPort}" ];
              labels = { host = config.networking.hostName; };
            }
          ];
        }
      ];

      services.monitoring.server.extraDashboards = [
        ./dashboard.json
      ];

      system.activationScripts.proxmox-pve-exporter = lib.stringAfter [ "agenixInstall" ] (
        if cfg.pveToken != null then ''
          # Declarative: pve.yml is derived from the agenix secret on every
          # activation (rotate = re-seal the secret, rebuild, switch).
          mkdir -p /var/lib/prometheus-pve-exporter
          user=$(${lib.getExe pkgs.gnused} -n 's/^PVE_USER=//p' ${config.age.secrets.prometheus-pve-exporter.path})
          token_name=$(${lib.getExe pkgs.gnused} -n 's/^PVE_TOKEN_NAME=//p' ${config.age.secrets.prometheus-pve-exporter.path})
          token_value=$(${lib.getExe pkgs.gnused} -n 's/^PVE_TOKEN_VALUE=//p' ${config.age.secrets.prometheus-pve-exporter.path})
          ${pkgs.coreutils}/bin/tee /var/lib/prometheus-pve-exporter/pve.yml >/dev/null <<EOF
default:
  user: "$user"
  token_name: "$token_name"
  token_value: "$token_value"
  verify_ssl: false
EOF
          chmod 0600 /var/lib/prometheus-pve-exporter/pve.yml
        '' else ''
          # Mutable fallback (no agenix secret configured): create the config
          # once, then paste the token into pve.yml by hand.
          mkdir -p /var/lib/prometheus-pve-exporter
          if [ ! -f /var/lib/prometheus-pve-exporter/pve.yml ]; then
            ${pkgs.coreutils}/bin/tee /var/lib/prometheus-pve-exporter/pve.yml >/dev/null <<'EOF'
default:
  user: "monitoring@pve"
  token_name: "monitoring"
  token_value: "replace-me-create-token-in-pve-ui"
  verify_ssl: false
EOF
          fi
          chmod 0600 /var/lib/prometheus-pve-exporter/pve.yml
        ''
      );

      age.secrets.prometheus-pve-exporter = lib.mkIf (cfg.pveToken != null) {
        file = cfg.pveToken;
        mode = "0400";
      };
    })
  ]);
}