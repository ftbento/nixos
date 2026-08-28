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

  workstation.ambxst = {
    enable = true;
    user = "benjidev";
  };

  # Hyprland uses hyprcursor; make sure the Bibata theme (set via stylix.cursor)
  # is also picked up by Hyprland instead of the default Hyprland logo cursor.

  # sddm picture
  systemd.tmpfiles.rules = [
    "f+ /var/lib/AccountsService/users/${username} 0600 root root - [User]\\nIcon=/var/lib/AccountsService/icons/${username}\\n"
    "L+ /var/lib/AccountsService/icons/${username} - - - - ${../config}/${username}.png"
  ];

  # secrets (agenix)
  age.identityPaths = [ "/home/${username}/.ssh/id_ed25519" ];
  age.secrets."github-ftbento" = {
    file = ../secrets/github-ftbento.age;
    owner = username;
  };
  age.secrets."cop3223c" = {
    file = ../secrets/cop3223c.age;
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

      # Hyprland uses hyprcursor; make sure the Bibata theme (set via stylix.cursor)
      # is also picked up by Hyprland instead of the default Hyprland logo cursor.
      pointerCursor.hyprcursor.enable = true;

      packages = with pkgs; [
        comma
        vesktop
        unzip
        opencode
        yt-dlp
        grc
        playerctl
        jq
        wlogout
        obsidian
        nerd-fonts.jetbrains-mono
        inputs.spotatui.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };

      # Hyprland window manager (system-side programs.hyprland stays in modules/wm/hyprland.nix)

      wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      configType = "hyprlang"; # SWITCH TO LUA
      # UWSM handles the systemd session integration
      systemd.enable = false;

      settings = {
        "$terminal" = "kitty";
        "$mainMod" = "SUPER";

        monitor = [
          ", preferred, auto, 1"
          "DP-5, 2560x1440@164.96, 0x0, 1"
          "HDMI-A-5, 1920x1080@60, 320x-1080, 1, transform, 2"
        ];

        workspace = [
          "1, monitor:DP-5"
          "2, monitor:DP-5"
          "3, monitor:DP-5"
          "4, monitor:DP-5"
          "5, monitor:DP-5"
          "6, monitor:HDMI-A-5"
          "7, monitor:HDMI-A-5"
          "8, monitor:HDMI-A-5"
          "9, monitor:HDMI-A-5"
          "10, monitor:HDMI-A-5"
        ];

        exec-once = [
          "ambxst"
          "hyprctl setcursor Bibata-Modern-Classic 24"
          "wl-paste --type text --watch cliphist store"
          "wl-paste --type image --watch cliphist store"
          "xrandr --output DP-5 --primary"
          "steam -silent"
        ];

        input = {
          kb_layout = "us";
          kb_options = "caps:super";
          sensitivity = -0.25;
          # 2: pointer (scroll) focus follows cursor, keyboard focus stays on last click
          follow_mouse = 2;
        };

        cursor = {
          no_hardware_cursors = true;
        };

        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          layout = "scrolling";
        };

        # Every window opens as a full-size column; scroll to move between them
        scrolling = {
          column_width = 1.0;
          fullscreen_on_one_column = true;
        };

        decoration = {
          rounding = 10;
          blur = {
            enabled = true;
            size = 4;
            passes = 2;
          };
        };

        animations = {
          enabled = true;

          bezier = [
            "easeOutCubic, 0.33, 1, 0.68, 1"
            "easeInOutCubic, 0.65, 0.05, 0.36, 1"
            "easeOutQuint, 0.23, 1, 0.32, 1"
            "snappy, 0.15, 0, 0.1, 1"
            "linear, 1, 1, 1, 1"
          ];

          animation = [
            "windows, 1, 7, easeOutQuint"
            "windowsOut, 1, 7, easeOutQuint, popin 80%"
            "border, 1, 10, easeOutCubic"
            "borderangle, 1, 8, easeInOutCubic"
            "fade, 1, 7, easeOutCubic"
            "workspaces, 1, 6, easeOutQuint"
            "windowsMove, 1, 7, easeOutQuint"
          ];
        };

        bind = [
          "$mainMod, D, exec, ambxst run launcher"
          "$mainMod, V, exec, ambxst run clipboard"
          "$mainMod, Q, killactive"
          "$mainMod, Return, exec, $terminal"
          "$mainMod, Escape, exec, ambxst lock"
          ", Print, exec, hyprshot -m region --clipboard-only"
          "$mainMod, Print, exec, hyprshot -m output --clipboard-only"
          "$mainMod SHIFT, Print, exec, hyprshot -m window --clipboard-only"
          "$mainMod, h, layoutmsg, focus l"
          "$mainMod, l, layoutmsg, focus r"
          "$mainMod, k, layoutmsg, focus u"
          "$mainMod, j, layoutmsg, focus d"
          "$mainMod, 1, workspace, 6"
          "$mainMod, 1, workspace, 1"
          "$mainMod, 2, workspace, 7"
          "$mainMod, 2, workspace, 2"
          "$mainMod, 3, workspace, 8"
          "$mainMod, 3, workspace, 3"
          "$mainMod, 4, workspace, 9"
          "$mainMod, 4, workspace, 4"
          "$mainMod, 5, workspace, 10"
          "$mainMod, 5, workspace, 5"
          "$mainMod SHIFT, 1, movetoworkspace, 1"
          "$mainMod SHIFT, 2, movetoworkspace, 2"
          "$mainMod SHIFT, 3, movetoworkspace, 3"
          "$mainMod SHIFT, 4, movetoworkspace, 4"
          "$mainMod SHIFT, 5, movetoworkspace, 5"
          "$mainMod, mouse_up, layoutmsg, move +col"
          "$mainMod, mouse_down, layoutmsg, move -col"
          "$mainMod SHIFT, h, layoutmsg, swapcol l"
          "$mainMod SHIFT, l, layoutmsg, swapcol r"
          "$mainMod SHIFT, k, layoutmsg, expel"
          "$mainMod SHIFT, j, layoutmsg, consume"
          "$mainMod CTRL, h, layoutmsg, colresize -conf"
          "$mainMod CTRL, l, layoutmsg, colresize +conf"
          "$mainMod CTRL, k, layoutmsg, colresize -0.05"
          "$mainMod CTRL, j, layoutmsg, colresize +0.05"
        ];

        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];
      };
    };

    # Themed by Stylix
    services.swaync.enable = true;
    programs.btop.enable = true;

    home.fastfetch.enable = true;

    home.fish = {
      enable = true;
      shellAliases = {
        nhswitch = "nh os switch ~/nixos";
        nhboot = "nh os boot  ~/nixos";
        nhtest = "nh os test ~/nixos";
        nhupdate = "nix flake update --flake ~/nixos && nh os switch  ~/nixos";
        nhclean = "nh clean all --keep-since 4d --keep 3";
        nhlist = "nixos-rebuild list-generations";
        ff = "fastfetch";

        spot = "spotatui";
        ".." = "cd ..";
        argon = "ssh argon";
        cop3223c = "ssh $(cat ${config.age.secrets."cop3223c".path})";
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

    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      
      settings = {
        "github.com" = {
          identityFile = config.age.secrets."github-ftbento".path;
          identitiesOnly = true;
        };

        "argon" = {
          HostName = "10.8.90.205";
          Port = 205;
          User = "benjidev";
        };
      };
    };
  };
}
