{ config, pkgs, inputs, ... }: let
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
      inputs.caelestia-shell.homeManagerModules.default
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
        cava
        playerctl
        jq
        wlogout
        nerd-fonts.jetbrains-mono
        swaynotificationcenter
        # inputs.spotatui.packages.${pkgs.stdenv.hostPlatform.system}.default
      ];
    };

    fonts.fontconfig.enable = true;

    xdg.configFile."hypr" = {
      source = ../config/hypr;
      recursive = true;
    };

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
        background_opacity = "0.5";
        background_blur = 5;
      };
    };

    programs.caelestia = {
      enable = true;
      systemd.enable = false;
      cli.enable = true;
    };

    home.yazi = {
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
