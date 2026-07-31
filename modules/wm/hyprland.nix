{ config, lib, pkgs, ... }: let
    cfg = config.workstation.hyprland;
  in
  {
  options.workstation.hyprland = {
    enable = lib.mkEnableOption "Hyprland compositor";
  };

  config = lib.mkIf cfg.enable {
    programs.hyprland = {
      enable = true;
      xwayland.enable = true;
      withUWSM = true;
    };

    environment.systemPackages = with pkgs; [
      kitty
      hyprcursor
      hyprutils
      hyprwayland-scanner
      hyprlock
      hyprpaper
      hyprshot
      wlogout
      btop
      fuzzel
      cliphist
      wl-clipboard
    ];

    security.pam.services.hyprlock = {};

  };
}
