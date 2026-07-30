{ config, lib, pkgs, ... }: {
  options.myDesktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland window manager";
  };

  config = lib.mkIf config.myDesktop.hyprland.enable {
    programs.hyprland.enable = true;
    services.xserver.enable = true;

    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
      extraPackages = with pkgs; [
        hyprland
        qt6.qtwayland
      ];
    };

    environment.sessionVariables = {
      WLR_NO_HARDWARE_CURSORS = "1";
      NIXOS_OZONE_WL = "1";
      LIBVA_DRIVER_NAME = "nvidia";
      __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      GBM_BACKEND = "nvidia-drm";
    };

    environment.systemPackages = with pkgs; [
      hyprland
      hyprpicker
      waybar
      wl-clipboard
    ];
  };
}