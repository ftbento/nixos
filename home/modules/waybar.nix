{ config, lib, ... }: {
  options.home.waybar = {
    enable = lib.mkEnableOption "waybar status bar";
  };

  config = lib.mkIf config.home.waybar.enable {
    programs.waybar.enable = true;

    xdg.configFile."waybar/config.jsonc".source = ../../config/waybar/waybar1/config.jsonc;
    xdg.configFile."waybar/style.css".source = ../../config/waybar/waybar1/style.css;

    # Our waybar config/style is fully custom, so keep Stylix from also writing
    # a style.css for waybar.
    stylix.targets.waybar.enable = lib.mkForce false;
  };
}
