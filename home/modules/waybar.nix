{ config, lib, pkgs, ... }: {
  options.myUser.waybar = {
    enable = lib.mkEnableOption "Waybar configuration";
  };

  config = lib.mkIf config.myUser.waybar.enable {
    programs.waybar = {
      enable = true;
      systemd.enable = true;
      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          height = 30;
          modules-left = [ "hyprland/workspaces" ];
          modules-center = [ "hyprland/window" ];
          modules-right = [ "pulseaudio" "network" "cpu" "memory" "clock" ];
          "hyprland/workspaces" = {
            format = "{name}";
          };
          "clock" = {
            format = "{:%H:%M}";
          };
        };
      };
      style = ''
        * {
          font-family: Roboto, Helvetica, Arial, sans-serif;
          font-size: 13px;
        }
        window#waybar {
          background-color: rgba(43, 48, 59, 0.5);
          color: #ffffff;
          transition-property: background-color;
          transition-duration: .5s;
        }
      '';
    };
  };
}
