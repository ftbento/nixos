# Reusable monitoring stack: Prometheus + Grafana (server facet) and
# node_exporter / cAdvisor (agent facet).
#
# Layout is hub-and-spoke over the tailnet:
#   agent  — every machine that exports metrics (node_exporter on port 9100,
#            optional cAdvisor for Docker container metrics)
#   server — the host that runs Prometheus + Grafana (bind Prometheus to
#            localhost, Grafana to the LAN/tailnet). Chosen by enabling
#            `services.monitoring.server`.
#
# Adding a new server later is two lines:
#   new host:    services.monitoring.exporter.enable = true
#   server host: services.monitoring.server.targets = [... ++ [{
#                  name = "<host>"; addr = "<host>.<tailnet>.ts.net";
#                }]];
# No IPs to hardcode — the server scrapes agents by their MagicDNS name.
#
# NOTE: container metrics use cAdvisor on port 9323, because nixpkgs (26.05)
# has no `services.prometheus.exporters.docker` module or docker exporter
# package. Port 9323 avoids the 8080 used by RackPeek on argon.

{ config, lib, pkgs, ... }:

let
  cfg = config.services.monitoring;
  cAdvisorPort = 9323;

  # Read-only dashboard directory in the store: Grafana's file provider only
  # reads from here (dashboards are stored in Grafana's own DB afterwards).
  dashboardsDir = pkgs.runCommand "grafana-dashboards" { } (
    ''
      mkdir -p $out
      cp ${./dashboard.json} $out/node-exporter.json
    '' + lib.concatMapStrings (dash: ''
      cp ${dash} $out/${baseNameOf dash}
    '') cfg.server.extraDashboards
  );

  nodeJob = {
    job_name = "node";
    scrape_interval = "30s";
    static_configs = map (t: {
      targets = [ "${t.addr}:${toString cfg.exporter.port}" ];
      labels = { host = t.name; };
    }) cfg.server.targets;
  };

  # NixOS starts each Docker container as its own systemd cgroup
  # (/system.slice/docker-<name>.service|.scope); under cAdvisor 0.56 these
  # series only carry an `id` label (no `name`). Keep app containers only and
  # expose a friendly `container` label for dashboards.
  dockerContainerRelabel = [
    {
      source_labels = [ "id" ];
      regex = "/system.slice/docker-(.+)\\..+";
      action = "keep";
    }
    {
      source_labels = [ "id" ];
      regex = "/system.slice/docker-(.+)\\..+";
      target_label = "container";
      replacement = "$1";
    }
  ];

  cAdvisorJob = {
    job_name = "cadvisor";
    scrape_interval = "30s";
    static_configs = [
      {
        targets = [ "127.0.0.1:${toString cAdvisorPort}" ];
        labels = { host = config.networking.hostName; };
      }
    ];
    metric_relabel_configs = dockerContainerRelabel;
  };

  # --- Alerting rules (Prometheus). Evaluated server-side, notifications via
  # Alertmanager -> alertmanager-ntfy -> ntfy phone push. ---
  prometheusAlertRules =
    [
      {
        alert = "NodeExporterDown";
        expr = ''up{job="node"} == 0'';
        for = "2m";
        labels = { severity = "critical"; host = config.networking.hostName; };
        annotations = {
          summary = "Node exporter unreachable on {{ $labels.host }}";
          description = "Prometheus has not scraped the node exporter for over 2 minutes.";
          resolved_summary = "Node exporter is reporting again";
          resolved_description = "Prometheus is successfully scraping the node exporter.";
        };
      }
      {
        alert = "PveExporterDown";
        expr = ''up{job="pve"} == 0'';
        for = "2m";
        labels = { severity = "critical"; host = config.networking.hostName; };
        annotations = {
          summary = "Proxmox VE exporter unreachable on {{ $labels.host }}";
          description = "The pve job has not been scraped for over 2 minutes; hypervisor metrics are stale.";
          resolved_summary = "Proxmox VE exporter is reporting again";
          resolved_description = "The pve scrape job is healthy again.";
        };
      }
      {
        alert = "HostLoadHigh";
        expr = ''node_load1 / scalar(count(node_cpu_seconds_total{mode="idle"})) > 0.75'';
        for = "10m";
        labels = { severity = "warning"; host = config.networking.hostName; };
        annotations = {
          summary = "Load above 75% of capacity on {{ $labels.host }}";
          description = "node_load1 / core count has been above 0.75 for 10 minutes.";
          resolved_summary = "Load is back to normal";
          resolved_description = "Load has dropped back below 75% of capacity.";
        };
      }
      {
        alert = "MemoryUsageHigh";
        expr = ''(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90'';
        for = "5m";
        labels = { severity = "warning"; host = config.networking.hostName; };
        annotations = {
          summary = "Memory usage above 90% on {{ $labels.host }}";
          description = "Available memory has been under 10% for 5 minutes.";
          resolved_summary = "Memory usage is back to normal";
          resolved_description = "Available memory is above 10% again.";
        };
      }
      {
        alert = "RootDiskSpaceLow";
        expr = ''(node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100 < 15'';
        for = "10m";
        labels = { severity = "warning"; host = config.networking.hostName; };
        annotations = {
          summary = "Root filesystem below 15% free on {{ $labels.host }}";
          description = "The root mount has under 15% free for 10 minutes (was {{ $value | humanize }}%).";
          resolved_summary = "Root disk space is back above 15% free";
          resolved_description = "The root mount has recovered.";
        };
      }
    ]
    ++ map (c: {
      alert = "ContainerDown";
      expr = "absent(container_start_time_seconds{container=\"${c}\"})";
      for = "2m";
      labels = { severity = "warning"; host = config.networking.hostName; };
      annotations = {
        summary = "Container ${c} not running";
        description = "cAdvisor stopped reporting the ${c} container over 2 minutes ago.";
        resolved_summary = "Container ${c} is back online";
        resolved_description = "cAdvisor is reporting the ${c} container successfully.";
      };
    }) cfg.server.alerting.containers;

  alertRuleFile = (pkgs.formats.yaml { }).generate "prometheus-alerts.yml" {
    groups = [
      {
        name = "host-alerts";
        rules = prometheusAlertRules;
      }
    ];
  };

  ntfyAlertUrl = "${cfg.server.alerting.ntfyUrl}/${cfg.server.alerting.ntfyTopic}";
in
{
  options.services.monitoring = {
    exporter = {
      enable = lib.mkEnableOption "Prometheus node exporter (agent side)";

      containerMetrics = lib.mkEnableOption ''
        cAdvisor container metrics. Only meaningful where Docker runs; keep off
        on plain machines.
      '';

      port = lib.mkOption {
        type = lib.types.port;
        default = 9100;
        description = "Port the node exporter listens on";
      };
    };

    server = {
      enable = lib.mkEnableOption "Prometheus server + Grafana (server side)";

      port = lib.mkOption {
        type = lib.types.port;
        default = 3000;
        description = "Port Grafana listens on";
      };

      targets = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Label used for this target in dashboards";
            };
            addr = lib.mkOption {
              type = lib.types.str;
              description = "Scrape address: hostname (MagicDNS) or IP";
            };
          };
        });
        default = [
          {
            name = config.networking.hostName;
            addr = "127.0.0.1";
          }
        ];
        description = "Hosts for the server to scrape with the node exporter";
      };

      extraScrapeConfigs = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = ''
          Extra Prometheus scrape_configs to append after the node/cAdvisor
          jobs. Used by feature modules (e.g. the Proxmox exporter) to feed
          Prometheus without touching the base jobs.
        '';
      };

      extraDashboards = lib.mkOption {
        type = lib.types.listOf lib.types.path;
        default = [ ];
        description = ''
          Paths to extra Grafana dashboard JSON files to provision next to the
          built-in node-exporter dashboard.
        '';
      };

      alerting = {
        enable = lib.mkEnableOption ''
          Prometheus alert rules + Alertmanager pushing phone notifications
          through alertmanager-ntfy to an ntfy server.
        '';

        ntfyUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://ntfy.sh";
          description = "Base URL of the ntfy server (public ntfy.sh or self-hosted).";
        };

        ntfyTopic = lib.mkOption {
          type = lib.types.str;
          description = ''
            ntfy topic every alert is published to (append it to ntfyUrl, e.g.
            https://ntfy.sh/<topic>). On ntfy.sh the topic name is effectively
            a password for that endpoint — keep it unguessable.
          '';
        };

        containers = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Docker container names to alert on when they stop being reported by
            cAdvisor (matches the `container` label, e.g. "obsidian-livesync").
          '';
        };
      };
    };
  };

  config = lib.mkIf (cfg.exporter.enable || cfg.server.enable) (lib.mkMerge [
    # --- Agent facet ---
    (lib.mkIf cfg.exporter.enable {
      services.prometheus.exporters.node = {
        enable = true;
        inherit (cfg.exporter) port;
        # Reachable from remote server hubs over the tailnet; the firewall is
        # only opened where interception is wanted (openFirewall = true).
      };
      services.prometheus.exporters.node.openFirewall = true;
    })

    # --- Container metrics (cAdvisor, localhost-only) ---
    (lib.mkIf cfg.exporter.containerMetrics {
      services.cadvisor = {
        enable = true;
        port = cAdvisorPort;
      };
    })

    # --- Server facet: Prometheus + Grafana ---
    (lib.mkIf cfg.server.enable {
      services.prometheus = {
        enable = true;
        # Only Grafana on this host talks to Prometheus; don't expose it.
        listenAddress = "127.0.0.1";
        scrapeConfigs =
          [ nodeJob ]
          ++ lib.optionals cfg.exporter.containerMetrics [ cAdvisorJob ]
          ++ cfg.server.extraScrapeConfigs;
      };

      services.grafana = {
        enable = true;
        settings = {
          server = {
            http_addr = "0.0.0.0";
            http_port = cfg.server.port;
          };
          # LAN/tailnet-only access, like RackPeek: no public sign-ups, no
          # telemetry out of the box.
          users.allow_sign_up = false;
          analytics.reporting_enabled = false;
        };
        # 26.05 removed the default secret key; keep a stable one for this host
        # by generating it once into the (persistent) state dir.
        settings.security.secret_key = "$__file{/var/lib/grafana/secret_key}";
        provision.datasources.settings = {
          apiVersion = 1;
          datasources = [
            {
              name = "Prometheus";
              type = "prometheus";
              access = "proxy";
              uid = "prometheus";
              url = "http://127.0.0.1:9090";
              isDefault = true;
            }
          ];
        };
        provision.dashboards.settings = {
          apiVersion = 1;
          providers = [
            {
              name = "default";
              options.path = dashboardsDir;
            }
          ];
        };
      };

      networking.firewall.allowedTCPPorts = [ cfg.server.port ];

      # Generate/keep the Grafana secret key so the `$__file{}` provider above
      # has something to read. Generated once, then persisted in the state dir.
      system.activationScripts.grafana-secret-key = lib.stringAfter [ "users" ] ''
        mkdir -p /var/lib/grafana
        if [ ! -f /var/lib/grafana/secret_key ]; then
          ${pkgs.openssl}/bin/openssl rand -hex 24 > /var/lib/grafana/secret_key
        fi
        chown grafana:grafana /var/lib/grafana/secret_key
        chmod 640 /var/lib/grafana/secret_key
      '';
    })

    # --- Alerting: rules + Alertmanager -> alertmanager-ntfy -> ntfy push ---
    (lib.mkIf cfg.server.alerting.enable {
      services.prometheus = {
        ruleFiles = [ alertRuleFile ];
        # Deliver firing alerts to the local Alertmanager on :9093.
        alertmanagers = [
          {
            static_configs = [ { targets = [ "127.0.0.1:9093" ]; } ];
          }
        ];
      };

      services.prometheus.alertmanager = {
        enable = true;
        configuration = {
          route = {
            receiver = "ntfy";
            group_by = [ "alertname" "host" ];
            group_wait = "10s";
            group_interval = "5m";
            repeat_interval = "4h";
          };
          receivers = [
            {
              name = "ntfy";
              webhook_configs = [
                { url = "http://127.0.0.1:8000/hook"; }
              ];
            }
          ];
        };
      };

      services.prometheus.alertmanager-ntfy = {
        enable = true;
        settings = {
          http.addr = "127.0.0.1:8000";
          ntfy = {
            baseurl = cfg.server.alerting.ntfyUrl;
            notification = {
              topic = cfg.server.alerting.ntfyTopic;
              priority = ''
                status == "firing" && severity == "critical" ? "urgent" : status == "firing" ? "high" : "default"
              '';
              tags = [
                {
                  tag = "green_circle";
                  condition = ''status == "resolved"'';
                }
                {
                  tag = "rotating_light";
                  condition = ''status == "firing"'';
                }
              ];
              templates = {
                title = ''
                  {{ if eq .Status "resolved" }}Resolved: {{ end }}{{ if eq .Status "resolved" }}{{ with index .Annotations "resolved_summary" }}{{ . }}{{ else }}{{ index .Annotations "summary" }}{{ end }}{{ else }}{{ index .Annotations "summary" }}{{ end }}
                '';
                description = ''
                  {{ if eq .Status "resolved" }}{{ with index .Annotations "resolved_description" }}{{ . }}{{ else }}{{ index .Annotations "description" }}{{ end }}{{ else }}{{ index .Annotations "description" }}{{ end }}
                '';
              };
            };
          };
        };
      };

      # Crash signal: this box can't alert about itself dying, so it pings the
      # topic the moment it boots. curl needs the sandbox of a onshot unit only.
      systemd.services.argon-boot-notify = {
        wantedBy = [ "multi-user.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${pkgs.curl}/bin/curl -sS -m 20 -d \"argon is back online\" -H \"Title: argon boot\" -H \"Tags: computer,argon\" ${ntfyAlertUrl}";
        };
      };
    })
  ]);
}