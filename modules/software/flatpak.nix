{ config, lib, pkgs, ... }: {
  options.workstation.flatpak = {
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

  config = {
    services.flatpak.enable = true;
    systemd.timers."flatpak-update" = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = config.workstation.flatpak.onCalendar;
        Persistent = true;
      };
    };
    systemd.services."flatpak-update" = {
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${lib.getExe pkgs.flatpak} update -y";
      };
    };
  };
}
