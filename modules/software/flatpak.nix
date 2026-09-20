{ config, lib, pkgs, ... }: {
  services.flatpak.enable = true;

  # Weekly Flatpak update timer
  systemd.timers."flatpak-update" = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
    };
  };
  systemd.services."flatpak-update" = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe pkgs.flatpak} update -y";
    };
  };
}