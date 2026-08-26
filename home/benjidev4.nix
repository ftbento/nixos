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

    # Hyprland window manager (system-side programs.hyprland stays in modules/wm/hyprland.nix).
    # This is the Lua variant; the whole config is provided via ../config/hypr/hyprland.lua
    # (kept in sync with benjidev.nix's hyprlang `settings`).
    wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      configType = "lua";
      # UWSM handles the systemd session integration
      systemd.enable = false;
      # Only used for the hyprlang variant; left empty so the module does not
      # generate a conflicting hyprland.lua (the file below is the source of truth).
      settings = { };
      extraConfig = "";
    };

    xdg.configFile."hypr/hyprland.lua".source = ../config/hypr/hyprland.lua;

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