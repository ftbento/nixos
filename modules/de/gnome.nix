{ config, lib, pkgs, ... }: let
    cfg = config.workstation.gnome;
  in {
  options.workstation.gnome = {
    enable = lib.mkEnableOption "GNOME desktop environment";
  };

  config = lib.mkIf cfg.enable {
    services.xserver.enable = true;
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;

    # Exclude default GNOME applications
    environment.gnome.excludePackages = with pkgs; [
      gnome-photos
      gnome-tour
      gnome-text-editor
    ];
  };
}