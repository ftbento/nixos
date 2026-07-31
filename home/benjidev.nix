{ config, pkgs, lib, inputs, ... }: let
  username = "benjidev";
in {
  # System-level user creation
  programs.fish.enable = true;
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
  };

  age.identityPaths = [ "/home/${username}/.ssh/id_ed25519" ];
  age.secrets."github-ftbento" = {
    file = ../secrets/github-ftbento.age;
    owner = username;
  };

  # Home Manager configuration
  home-manager.users.${username} = {
    imports = [
      ./modules
    ];

    home = {
      username = username;
      homeDirectory = "/home/${username}";
      stateVersion = "26.05";
      packages = with pkgs; [
        vesktop
        unzip
        opencode
        yt-dlp
        grc
        playerctl
        jq
        wlogout
        nerd-fonts.jetbrains-mono
        # inputs.spotatui.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };

    fonts.fontconfig.enable = true;

    # Hyprland window manager (system-side programs.hyprland stays in modules/wm/hyprland.nix)
    wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      configType = "hyprlang";
      # UWSM handles the systemd session integration
      systemd.enable = false;

      settings = {
        "$terminal" = "kitty";
        "$mainMod" = "SUPER";

        monitor = [
          ", preferred, auto, 1"
          "DP-1, 2560x1440@164.96, 0x0, 1"
          "HDMI-A-1, 1920x1080@60, 2560x0, 1, transform, 3"
        ];

        exec-once = [
          "hyprpaper"
          "hyprctl setcursor Bibata-Modern-Classic 24"
        ];

        input = {
          kb_layout = "us";
          sensitivity = 0;
          follow_mouse = 1;
          touchpad = {
            natural_scroll = true;
          };
        };

        cursor = {
          no_hardware_cursors = true;
        };

        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          layout = "dwindle";
        };

        decoration = {
          rounding = 10;
          blur = {
            enabled = true;
            size = 4;
            passes = 2;
          };
        };

        bind = [
          "$mainMod, D, exec, fuzzel"
          "$mainMod, Q, killactive"
          "$mainMod, Return, exec, $terminal"
          "$mainMod, L, exec, hyprlock"
          ", Print, exec, hyprshot -m output --clipboard-only"
          "$mainMod, Print, exec, hyprshot -m region --clipboard-only"
          "$mainMod SHIFT, Print, exec, hyprshot -m window --clipboard-only"
          "$mainMod, left, movefocus, l"
          "$mainMod, right, movefocus, r"
          "$mainMod, up, movefocus, u"
          "$mainMod, down, movefocus, d"
          "$mainMod, 1, workspace, 1"
          "$mainMod, 2, workspace, 2"
          "$mainMod, 3, workspace, 3"
          "$mainMod, 4, workspace, 4"
          "$mainMod, 5, workspace, 5"
          "$mainMod, 6, workspace, 6"
          "$mainMod, 7, workspace, 7"
          "$mainMod, 8, workspace, 8"
          "$mainMod, 9, workspace, 9"
          "$mainMod, 0, workspace, 10"
          "$mainMod ALT, 1, movetoworkspace, 1"
          "$mainMod ALT, 2, movetoworkspace, 2"
          "$mainMod ALT, 3, movetoworkspace, 3"
          "$mainMod ALT, 4, movetoworkspace, 4"
          "$mainMod ALT, 5, movetoworkspace, 5"
          "$mainMod ALT, 6, movetoworkspace, 6"
          "$mainMod ALT, 7, movetoworkspace, 7"
          "$mainMod ALT, 8, movetoworkspace, 8"
          "$mainMod ALT, 9, movetoworkspace, 9"
          "$mainMod ALT, 0, movetoworkspace, 10"
          "$mainMod SHIFT, left, movewindow, l"
          "$mainMod SHIFT, right, movewindow, r"
          "$mainMod SHIFT, up, movewindow, u"
          "$mainMod SHIFT, down, movewindow, d"
          "$mainMod CTRL, left, resizeactive, -30 0"
          "$mainMod CTRL, right, resizeactive, 30 0"
          "$mainMod CTRL, up, resizeactive, 0 -30"
          "$mainMod CTRL, down, resizeactive, 0 30"
        ];
      };
    };

    # Lock screen (colors from Stylix, per-monitor backgrounds kept manual)
    programs.hyprlock = {
      enable = true;
      package = null;
      settings = {
        general = {
          hide_cursor = true;
          no_fade_in = false;
          ignore_empty_input = true;
          grace = 5;
        };

        background = lib.mkForce [
          {
            monitor = "DP-1";
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
          {
            monitor = "HDMI-A-1";
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
          monitor = "DP-1";
          size = "300, 50";
          outline_thickness = 2;
          dots_size = 0.2;
          dots_spacing = 0.35;
          dots_center = true;
          fade_on_empty = true;
          placeholder_text = "<i>Password...</i>";
          hide_input = false;
          fail_text = "<b>Wrong!</b>";
          fail_timeout = 2000;
          capslock_color = -1;
          position = "0, -50";
          halign = "center";
          valign = "center";
        };

        label = [
          {
            monitor = "DP-1";
            text = "cmd[update:1000] echo \"$(date '+%H:%M')\"";
            color = "#ffffff";
            font_size = 48;
            font_family = "JetBrainsMono Nerd Font";
            position = "0, -120";
            halign = "center";
            valign = "center";
          }
          {
            monitor = "DP-1";
            text = "cmd[update:1000] echo \"$(date '+%A, %d %B %Y')\"";
            color = "rgba(255, 255, 255, 0.7)";
            font_size = 16;
            font_family = "JetBrainsMono Nerd Font";
            position = "0, -80";
            halign = "center";
            valign = "center";
          }
          {
            monitor = "HDMI-A-1";
            text = "cmd[update:1000] echo \"$(date '+%H:%M')\"";
            color = "#ffffff";
            font_size = 48;
            font_family = "JetBrainsMono Nerd Font";
            position = "0, -120";
            halign = "center";
            valign = "center";
          }
          {
            monitor = "HDMI-A-1";
            text = "cmd[update:1000] echo \"$(date '+%A, %d %B %Y')\"";
            color = "rgba(255, 255, 255, 0.7)";
            font_size = 16;
            font_family = "JetBrainsMono Nerd Font";
            position = "0, -80";
            halign = "center";
            valign = "center";
          }
        ];
      };
    };

    # Wallpaper daemon (static config; Stylix takes over only if stylix.image is set)
    xdg.configFile."hypr/hyprpaper.conf".source = ../config/hypr/hyprpaper.conf;

    # Themed by Stylix
    services.swaync.enable = true;
    programs.fuzzel.enable = true;
    programs.btop.enable = true;

    home.fastfetch.enable = true;

    home.fish = {
      enable = true;
      shellAliases = {
        nhswitch = "nh os switch ~/nixos";
        nhboot = "nh os boot  ~/nixos";
        nhupdate = "nix flake update --flake ~/nixos && nh os switch  ~/nixos";
        nhclean = "nh clean all --keep-since 4d --keep 3";
        nhlist = "nixos-rebuild list-generations";
        ff = "fastfetch";
        ".." = "cd ..";
      };
    };

    home.git = {
      enable = true;
      userName = "ftbento";
      userEmail = "ftbento@users.noreply.github.com";
    };

    home.kitty = {
      enable = true;
      settings = {
        confirm_os_window_close = 0;
        dynamic_background_opacity = true;
        enable_audio_bell = false;
        mouse_hide_wait = "-1.0";
        window_padding_width = 10;
        background_blur = 5;
      };
    };

    home.yazi = {
      enable = true;
    };

    # cava audio visualizer — enabled via HM so Stylix can theme it
    programs.cava = {
      enable = true;
    };

    # Theme cava with a base16 gradient (the only cava theming mode Stylix has)
    stylix.targets.cava.rainbow.enable = true;

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      
      settings = {
        "github.com" = {
          identityFile = config.age.secrets."github-ftbento".path;
          identitiesOnly = true;
        };
      };
    };
  };
}
