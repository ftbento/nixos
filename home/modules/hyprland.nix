{ config, lib, pkgs, ... }: {
  options.myUser.hyprland = {
    enable = lib.mkEnableOption "Hyprland configuration";
  };

  config = lib.mkIf config.myUser.hyprland.enable {
    home.packages = with pkgs; [
    hyprcursor
    hyprutils
    hyprwayland-scanner
    ];

    xdg.configFile."hypr/hyprland.conf".text = ''
      monitors=
      workspace = 1
      workspace = 2
      workspace = 3
      workspace = 4
      workspace = 5
      workspace = 6

      $terminal = kitty

      input {
        kb_layout = us
        kb_variant =
        options =
        repeat_rate = 25
        repeat_delay = 400
        sensitivity = 0
        touch {
          natural_scroll = true
          left_handed = 0
        }
      }

      general {
        gaps_in = 4
        gaps_out = 8
        border_size = 2
        col.active_border = rgba(89b4fa,ff) rgba(cba6f7,ff) 45deg
        col.inactive_border = rgba(585b70,ff)
        allow_tearing = 0
        resize_corner = 13
      }

      decoration {
        rounding = 12
        blur {
          enabled = 1
          size = 8
          passes = 2
        }
        drop_shadow = 1
        shadow_range = 15
        shadow_render_power = 15
        col.shadow = rgba(000000,aa)
      }

      animations {
        enabled = 1
        bezier = myBezier, 0.05, 0.9, 0.1, 1.05
        animation = windows, 1, 7, myBezier
        animation = windowsOut, 1, 7, default, popin 80%
        animation = borders, 1, 10, default
        animation = borderangle, 1, 8, default
        animation = fade, 1, 7, default
        animation = workspaces, 1, 6, default
      }

      dwindle {
        pseudotile = 1
        preserve_split = 1
      }

      master {
        new_status = master
        fake_outputs = 1
      }

      misc {
        disable_hyprland_logo = 1
        disable_splash_rendering = 1
        vfr = 1
      }

      binds = $terminal kill, killactive, fullscreen, fakefullscreen, closewindow, togglefloating, workspace, movetoworkspace, movetoworkspacesilent, recenter, togglegroup, movegroup, movefocus, changeworkspace, togglegroups

      windowrulev2 = suppressevent maximize, class:^(.*)$
      windowrulev2 = workspace 1, class:^(kitty)$

      exec-once = waybar
      bind = SUPER, D, exec, wofi --show drun
    '';
  };
}