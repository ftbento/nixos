{ lib, pkgs, ... }: {
  environment.systemPackages = with pkgs; [
    hyprlock
  ];

  # Required for hyprlock to authenticate via PAM
  security.pam.services.hyprlock = {};

  home-manager.users.benjidev.programs.hyprlock = {
      enable = true;
      package = null;
      settings = {
        general = {
          hide_cursor = true;
          no_fade_in = false;
          ignore_empty_input = true;
          grace = 5;
        };

        # TODO: might be redundant with silent sddm?
        background = lib.mkForce [
          {
            monitor = "DP-5";
            path = "/home/benjidev/Pictures/Wallpapers/default.jpg";
            color = "rgba(21, 18, 27, 1.0)";
            blur_passes = 2;
            blur_size = 4;
            noise = 0.01;
            contrast = 0.8;
            brightness = 0.7;
            vibrancy = 0.2;
            vibrancy_darkness = 0.1;
          }
          # second monitor wallpaper
          {
            monitor = "HDMI-A-5";
            path = "/home/benjidev/Pictures/Wallpapers/default.jpg";
            color = "rgba(21, 18, 27, 1.0)";
            blur_passes = 2;
            blur_size = 4;
            noise = 0.01;
            contrast = 0.8;
            brightness = 0.7;
            vibrancy = 0.2;
            vibrancy_darkness = 0.1;
          }
        ];

        input-field = {
          monitor = "DP-5";
          size = "300, 50";
          outline_thickness = 2;
          dots_size = 0.2;
          dots_spacing = 0.35;
          dots_center = true;
          fade_on_empty = true;
          placeholder_text = "<i>Password...</i>";
          hide_input = false;
          fail_text = "...";
          fail_timeout = 2000;
          capslock_color = -1;
          position = "0, 200";
          halign = "center";
          valign = "center";
        };

        label = [
          {
            monitor = "DP-5";
            text = "cmd[update:1000] echo \"$(date '+%H:%M')\"";
            color = "#ffffff";
            font_size = 48;
            font_family = "JetBrainsMono Nerd Font";
            position = "0, -120";
            halign = "center";
            valign = "center";
          }
          # Time
          {
            monitor = "DP-5";
            text = "cmd[update:1000] echo \"<b><big> $(date +\"%I:%M:%S %p\") </big></b>\"";
            color = "rgba(255, 255, 255, 0.7)";
            font_size = 94;
            font_family = "JetBrainsMono Nerd Font";
            position = "0, 0";
            halign = "center";
            valign = "center";
          }
          # User
          {
            monitor = "DP-5";
            text = "   $USER";
            color = "$color12";
            font_size = 18;
            font_family = "JetBrainsMono Nerd Font";

            position = "0, 100";
            halign = "center";
            valign = "bottom";
          }
        ];
      };
    };
}
