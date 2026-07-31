{ config, lib, pkgs, ... }: let
  cfg = config.workstation.flatpak;
in {
  options.workstation.flatpak = {
    enable = lib.mkEnableOption "Flatpak package management";
    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "weekly";
      description = "Flatpak update schedule (systemd timer)";
    };
    packages = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Flatpak packages to install system-wide";
    };
  };

  config = lib.mkIf cfg.enable {
    services.flatpak.enable = true;
    systemd.timers."flatpak-update" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        Persistent = true;
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe pkgs.flatpak} update -y";
      };
    };
  };
}
