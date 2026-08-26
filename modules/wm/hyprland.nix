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
      hyprshot
      wlogout
      btop
      cliphist
      wl-clipboard
      xorg.xrandr
    ];

  };
}
