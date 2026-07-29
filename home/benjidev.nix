{ config, pkgs, inputs, ... }: {
  # System-level user creation
  programs.fish.enable = true;
  users.users.benjidev = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    shell = pkgs.fish;
  };

  # Home Manager configuration
  home-manager.users.benjidev = {
    imports = [ ./modules ];

    home = {
      username = "benjidev";
      homeDirectory = "/home/benjidev";
      stateVersion = "25.11";
      packages = with pkgs; [
        # Desktop Apps
        vesktop
        opencode

        # CLI
        kitty
        grc
      ];
    };

    myUser.fish = {
      enable = true;
      shellAliases = {
        nhswitch = "nh os switch ~/nixos";
        nhboot = "nh os boot  ~/nixos";
        nhupdate = "nix flake update --flake ~/nixos && nh os switch  ~/nixos";
        nhclean = "nh clean all";

        ff = "fastfetch";

        ".." = "cd ..";
      };
    };

    myUser.git = {
      enable = true;
      userName = "ftbento";
      userEmail = "ftbento@users.noreply.github.com";
    };

    myUser.kitty = {
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

    myUser.fastfetch = {
      enable = true;
    };

    # age.secrets."github-ssh-key" = {
    #   file = ../../../secrets/github-ssh-key.age;
    # };
    # programs.ssh = {
    #   enable = true;
    #   matchBlocks = {
    #     "github.com" = {
    #       identityFile = "/run/agenix/github-ssh-key";
    #       identitiesOnly = true;
    #     };
    #   };
    # };
  };
}
