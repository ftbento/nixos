# Reusable services dashboard: a landing page for everything a host exposes.
#
# Serves Homepage (gethomepage.dev) behind nginx on port 80:
#   web UI services  -> clickable cards with optional up/latency status checks
#   non-web services -> cards that link to a generated /info/<slug> page
#                       explaining how to use the service
#
# Homepage is a NixOS module (`services.homepage-dashboard`) whose config
# files are written read-only into /etc (the nix store) - the same
# "Nix is the source of truth" philosophy used for RackPeek on argon. The
# dashboard UI only ever runs on localhost; nginx is the single public door.
#
# Adding this to a new server is enable + a service list, and every entry can
# point at any IP/hostname (it's just a link):
#   imports = [ ../../modules/services/dashboard ];
#   services.dashboard = {
#     enable = true;
#     allowedHosts = [ "host.tailnet-name.ts.net" "192.168.1.10" ];
#     services = [
#       { name = "Grafana"; href = "http://host..."; siteMonitor = "..."; }
#       { name = "SSH"; info = "...usage instructions..."; ping = "..."; }
#     ];
#   };
#
# NOTE: service icons are fetched from CDNs by the browser, so they need a
# working internet connection (or browser cache). Offline they degrade to the
# default placeholder icon.

{ config, lib, pkgs, ... }:

let
  cfg = config.services.dashboard;

  # --- Escaping & slug helpers ---------------------------------------------
  escapeHtml = s: lib.replaceStrings
    [ "&" "<" ">" "\"" "'" ]
    [ "&amp;" "&lt;" "&gt;" "&quot;" "&#x27;" ]
    s;

  # "Obsidian LiveSync" -> "obsidian-livesync" (keeps [a-z0-9], dashes others)
  slugOf = name:
    lib.replaceStrings [ "--" ] [ "-" ]
      (lib.concatMapStrings (c:
        if builtins.match "[A-Za-z0-9]" c == null then "-"
        else lib.toLower c) (lib.stringToCharacters name));

  # --- Generated /info pages ------------------------------------------------
  template = builtins.readFile ./info-template.html;

  infoPage = { title, serviceName, description, usage, backHref }:
    lib.replaceStrings
      [ "@@TITLE@@" "@@SERVICE_NAME@@" "@@DESCRIPTION@@" "@@USAGE@@" "@@BACK_HREF@@" ]
      [ (escapeHtml title) (escapeHtml serviceName) (escapeHtml description) usage (escapeHtml backHref) ]
      template;

  infoServices = lib.filter (s: s.info != null) cfg.services;

  indexPage = infoPage {
    title = cfg.title;
    serviceName = "Service documentation";
    description = "Services on ${config.networking.hostName} that have no web UI.";
    usage = ''
      <ul class="index">
      ${lib.concatMapStrings (svc: ''
        <li><a href="${svc.slug}.html">${escapeHtml svc.name}</a><p>${escapeHtml (builtins.toString svc.description)}</p></li>
      '') infoServices}
      </ul>
    '';
    backHref = "/";
  };

  infoSite = pkgs.runCommand "dashboard-info-pages" { } (
    "mkdir -p $out\n"
    + lib.concatMapStrings (p: ''
      cat > $out/${p.name} <<'__DASHBOARD_EOF__'
      ${p.value}
      __DASHBOARD_EOF__
    '') ([ { name = "index.html"; value = indexPage; } ] ++ map (svc: {
      name = "${svc.slug}.html";
      value = infoPage {
        title = cfg.title;
        serviceName = svc.name;
        description = builtins.toString svc.description;
        usage = "<pre>${escapeHtml svc.info}</pre>";
        backHref = "/";
      };
    }) infoServices)
  );

  # --- Homepage rendering ---------------------------------------------------
  groupNames = lib.unique (map (s: s.group) cfg.services);

  homepageCard = svc:
    (lib.optionalAttrs (svc.href != null) { href = svc.href; })
    // (lib.optionalAttrs (svc.info != null) { href = "/info/${svc.slug}.html"; })
    // (lib.optionalAttrs (svc.description != null) { description = svc.description; })
    // (lib.optionalAttrs (svc.icon != null) { icon = svc.icon; })
    // (lib.optionalAttrs (svc.siteMonitor != null) { siteMonitor = svc.siteMonitor; })
    // (lib.optionalAttrs (svc.ping != null) { ping = svc.ping; })
    // svc.extra;

  # services.yaml shape: [ { GroupName = [ { ServiceName = {...} } ... ] } ... ]
  homepageServices = map (g: {
    ${g} = map (svc: { ${svc.name} = homepageCard svc; })
      (lib.filter (s: s.group == g) cfg.services);
  }) groupNames;

  homepageSettings = {
    title = cfg.title;
    description = cfg.description;
    theme = cfg.theme;
    color = cfg.color;
    # Info pages are also served by us, open everything in a new tab.
    target = "_blank";
    statusStyle = "dot";
    hideVersion = true;
    disableUpdateCheck = true;
    disableIndexing = true;
    layout = lib.genAttrs groupNames (g: { style = "row"; columns = cfg.columns; });
  };

  homepageWidgets = lib.mkIf cfg.headerWidgets [
    { greeting = { text_size = "xl"; }; }
    { search = { provider = "duckduckgo"; target = "_blank"; }; }
    { resources = { cpu = true; memory = true; disk = "/"; }; }
    { datetime = { format = { timeStyle = "short"; dateStyle = "medium"; }; }; }
  ];
in
{
  options.services.dashboard = {
    enable = lib.mkEnableOption "services dashboard (Homepage behind nginx)";

    port = lib.mkOption {
      type = lib.types.port;
      default = 80;
      description = "Public port nginx serves the dashboard on";
    };

    homepagePort = lib.mkOption {
      type = lib.types.port;
      default = 8082;
      description = "Internal localhost port Homepage listens on (never opened in the firewall)";
    };

    title = lib.mkOption {
      type = lib.types.str;
      default = "${config.networking.hostName} services";
      description = "Dashboard page title";
    };

    description = lib.mkOption {
      type = lib.types.str;
      default = "Services hosted on ${config.networking.hostName}";
      description = "Subtitle shown under the dashboard title";
    };

    theme = lib.mkOption {
      type = lib.types.enum [ "dark" "light" ];
      default = "dark";
      description = "Homepage color theme";
    };

    color = lib.mkOption {
      type = lib.types.str;
      default = "slate";
      description = "Homepage color palette (slate, blue, ...)";
    };

    columns = lib.mkOption {
      type = lib.types.int;
      default = 4;
      description = "Service cards per row in each group";
    };

    headerWidgets = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Show the classic Homepage header: greeting, search, resource and clock
        widgets. The CPU resource widget also widens the hardened systemd
        sandbox to expose /proc.
      '';
    };

    allowedHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "courier.tailnet-name.ts.net" "192.168.1.10" ];
      description = ''
        Host headers Homepage accepts. Must cover every name/IP used to reach
        the dashboard through nginx (the browser sends that as the Host
        header): typically the tailnet MagicDNS name plus the LAN IP.
      '';
    };

    services = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule ({ config, ... }: {
        options = {
          group = lib.mkOption {
            type = lib.types.str;
            default = "Services";
            description = "Dashboard group this card appears under";
          };
          name = lib.mkOption {
            type = lib.types.str;
            description = "Service name shown on the card (unique per group)";
          };
          slug = lib.mkOption {
            type = lib.types.str;
            description = "Path of the /info/<slug> page (defaults to a sanitized name)";
          };
          description = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Short subtitle shown under the card title";
          };
          icon = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Homepage icon reference (si-X, mdi-X, sh-X or a dashboard-icons
              name). Fetched from a CDN by the browser.
            '';
          };
          href = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "External URL for web-UI services";
          };
          siteMonitor = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "HTTP URL health-checked for up/latency status";
          };
          ping = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "ICMP host for connectivity-only status (no web UI)";
          };
          info = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = ''
              Usage instructions for services without a web UI. Rendered as an
              /info/<slug> page; the card links there instead of out. If href
              is also set, the card still points at the info page.
            '';
          };
          extra = lib.mkOption {
            type = lib.types.attrs;
            default = { };
            description = "Extra Homepage card fields merged into this card";
          };
        };
        config.slug = lib.mkDefault (slugOf config.name);
      }));
      default = [ ];
      example = [
        {
          name = "Grafana";
          group = "Dashboards";
          href = "http://monitoring.host:3000";
          siteMonitor = "http://monitoring.host:3000";
        }
        {
          name = "SSH";
          info = "ssh root@server -p 205";
          ping = "server";
        }
      ];
      description = "Services shown on the dashboard";
    };
  };

  config = lib.mkIf cfg.enable {
    services.homepage-dashboard = {
      enable = true;
      listenPort = cfg.homepagePort;
      openFirewall = false; # only nginx is reachable
      allowedHosts = lib.concatStringsSep "," (cfg.allowedHosts ++ [ "localhost" "127.0.0.1" ]);
      settings = homepageSettings;
      services = homepageServices;
      widgets = homepageWidgets;
    };

    services.nginx = {
      enable = true;
      virtualHosts.dashboard = {
        listen = [{
          addr = "0.0.0.0";
          port = cfg.port;
        }];
        locations = {
          "/info/" = {
            alias = "${infoSite}/";
          };
          "= /info" = {
            return = "302 /info/";
          };
          "/" = {
            proxyPass = "http://127.0.0.1:${toString cfg.homepagePort}/";
          };
        };
      };
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}