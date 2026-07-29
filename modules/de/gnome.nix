{ config, pkgs, ... }: {
  services.xserver.enable = true;
  services = {
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
  };

  # Exclude some GNOME default apps
  environment.gnome.excludePackages = with pkgs; [
    gnome-photos
    gnome-tour
    gnome-text-editor
  ];
}
