# llama-swap — an on-demand model loader + proxy in front of llama.cpp's
# `llama-server`. A request for a model ID starts that model's server process
# (evicting the previously loaded one, governed by its `ttl`), then proxies the
# OpenAI-compatible API through. This is what lets one box expose several GGUF
# models without keeping them all resident in VRAM/RAM.
#
# We deliberately do NOT reuse nixpkgs' `services.llama-swap`: it runs the
# service under DynamicUser + PrivateUsers + MemoryDenyWriteExecute, which
# break access to GPU render nodes (/dev/dri/renderD*) and some Vulkan
# userspace. Instead we run a dedicated system user that is a member of the
# video/render groups and keep the sandbox GPU-friendly.

{ config, lib, pkgs, ... }:

let
  cfg = config.services.llamaSwap;
  settingsFormat = pkgs.formats.yaml { };
  configFile = settingsFormat.generate "llama-swap-config.yaml" cfg.settings;
in
{
  options.services.llamaSwap = {
    enable = lib.mkEnableOption "llama-swap model-swapping proxy for llama.cpp";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.llama-swap;
      defaultText = lib.literalExpression "pkgs.llama-swap";
      description = "The llama-swap package to run.";
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Address llama-swap listens on.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 9100;
      description = "Port llama-swap listens on.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Open {option}`port` to everyone. For a LAN-only deployment prefer
        leaving this off and adding a source-restricted rule via
        `networking.firewall.extraCommands` instead.
      '';
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "llama-swap";
      description = "System user the service (and the servers it spawns) runs as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "llama-swap";
      description = "System group the service runs as.";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "video" "render" ];
      description = ''
        Supplementary groups for the service user. `video`/`render` grant
        access to the GPU device nodes — required for Vulkan/CUDA builds.
      '';
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment variables for llama-swap and its servers.";
    };

    settings = lib.mkOption {
      type = lib.types.submodule { freeformType = settingsFormat.type; };
      default = { };
      description = ''
        llama-swap YAML configuration: `models`, `macros`, `healthCheckTimeout`,
        `globalTTL`, ... See the upstream `config.example.yaml`
        (https://github.com/mostlygeek/llama-swap/blob/main/config.example.yaml).
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.groups.${cfg.group} = { };
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = cfg.extraGroups;
      home = "/var/lib/llama-swap";
    };

    # Writable home for the Vulkan/RADV shader cache and anything else the
    # backend wants to persist. modelsDir is owned here too so the service can
    # read (and, if configured, download) weights without being root.
    systemd.tmpfiles.rules = [
      "d /var/lib/llama-swap 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.llama-swap = {
      description = "llama-swap model-swapping proxy for llama.cpp";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      environment = cfg.environment // {
        HOME = "/var/lib/llama-swap";
      };
      serviceConfig = {
        Type = "exec";
        ExecStart = "${lib.getExe cfg.package} --listen=${cfg.listenAddress}:${toString cfg.port} --config=${configFile}";
        Restart = "on-failure";
        RestartSec = 3;

        User = cfg.user;
        Group = cfg.group;
        SupplementaryGroups = cfg.extraGroups;
        WorkingDirectory = "/var/lib/llama-swap";

        # GPU + llama.cpp need the device tree and a writable /tmp; keep the
        # rest reasonable. ProtectSystem=full (not strict) leaves /var writable
        # so the GPU userspace can cache compiled shaders.
        PrivateDevices = false;
        PrivateTmp = true;
        ProtectSystem = "full";
        ProtectHome = true;
        NoNewPrivileges = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        ProtectClock = true;
        ProtectHostname = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        LockPersonality = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
        SystemCallArchitectures = "native";
      };
    };

    networking.firewall = lib.mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
