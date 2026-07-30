{ config, pkgs, inputs, ... }: let
  username = "benjidev";
in {
  programs.fish.enable = true;
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    shell = pkgs.fish;
  };

  age.identityPaths = [ "/home/${username}/.ssh/id_ed25519" ];
  age.secrets."github-ftbento" = {
    file = ../secrets/github-ftbento.age;
    owner = username;
  };

  home-manager.users.${username} = {
    imports = [
      ./modules
    ];

    home = {
      username = username;
      homeDirectory = "/home/${username}";
      stateVersion = "25.11";
      packages = with pkgs; [
        vesktop
        opencode
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

    myUser.hyprland.enable = true;
    myUser.waybar.enable = true;
    myUser.wofi.enable = true;

    myUser.fastfetch = {
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
