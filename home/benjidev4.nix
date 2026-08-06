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

  # workstation.ambxst = {
  #   enable = true;
  #   user = "benjidev";
  # };

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
        comma
        vesktop
        unzip
        opencode
        yt-dlp
        grc
        playerctl
        jq
        wlogout
        nerd-fonts.jetbrains-mono
        inputs.spotatui.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };

    # Hyprland window manager (system-side programs.hyprland stays in modules/wm/hyprland.nix)
      
    wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      configType = "lua";
      extraConfig = ''
        hl.monitor({
            output   = "DP-1",
            mode     = "2560x1440@164.96",
            position = "0x0",
            scale    = 1,
        })

        hl.monitor({
            output   = "HDMI-A-1",
            mode     = "1920x1080@60",
            position = "2560x0",
            scale    = 1,
            transform = 3,
        })

        require("hyprland-shared")
      '';
    };

    # Import shared hyprland.lua rules after
    xdg.configFile."hypr/hyprland.lua".source = ../config/hypr/hyprland.lua;

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

        # TODO: might be redundant with silent sddm?
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
          # second monitor wallpaper
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
          fail_text = "...";
          fail_timeout = 2000;
          capslock_color = -1;
          position = "0, 200";
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
          # Time
          {
            monitor = "DP-1";
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
            monitor = "DP-1";
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

    # Wallpaper daemon (static config; Stylix takes over only if stylix.image is set)
    xdg.configFile."hypr/hyprpaper.conf".source = ../config/hypr/hyprpaper.conf;

    # Themed by Stylix
    services.swaync.enable = true;
    programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          # Anchor Fuzzel to the bottom of the screen
          anchor = "bottom";

          y-margin = 20;

          # Standard clean launcher settings
          lines = 8;
          width = 32;
          horizontal-pad = 24;
          vertical-pad = 18;
          inner-pad = 12;
          line-height = 26;
          image-size-ratio = 0.5;
          prompt = "❯ ";
        };

        border = {
          width = 2;
          radius = 16;
        };
      };
    };
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
      };
    };
  };
}
