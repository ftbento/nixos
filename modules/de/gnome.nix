{ config, lib, pkgs, ... }: {
  options.myDesktop.gnome = {
    enable = lib.mkEnableOption "GNOME desktop environment";
  };

  config = lib.mkIf config.myDesktop.gnome.enable {
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