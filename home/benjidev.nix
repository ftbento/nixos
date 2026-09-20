{ config, pkgs, lib, inputs, ... }: let
  # Follow the host's primary user (workstation.user, modules/core/user.nix)
  username = config.workstation.user;

  pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in {
  # System-level user creation
  programs.fish.enable = true;
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish;
  };

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

  # Home Manager configuration — shared user profile. Desktop-specific bits
  # (Hyprland, desktop apps) live in profiles/desktop.nix; host display bits
  # (wallpapers, widgets) live in the host file.
  home-manager.users.${username} = {
    imports = [
      ./modules
    ];

    home = {
      username = username;
      homeDirectory = "/home/${username}";
      stateVersion = "26.05";

      packages = with pkgs; [
        bitwarden-desktop
        comma
        unzip
        yt-dlp
        grc
        pkgs-unstable.opencode
        playerctl
        jq
      ];
    };

    programs.btop.enable = true;

    # Silence xdg-desktop-portal 1.17 config warning (default backend set at
    # the NixOS system level in modules/software/rustdesk.nix).
    xdg.portal.config.common.default = "*";

    # Shared user modules with config baked in. Only enable + per-user overrides.
    home.fastfetch.enable = true;
    home.yazi.enable = true;
    home.git = {
      enable = true;
      userName = "ftbento";
      userEmail = "ftbento@users.noreply.github.com";
    };
    home.kitty.enable = true;
    home.fish = {
      enable = true;
      extraAliases = {
        # Needs the decrypted agenix path, which is only available in NixOS scope.
        cop3223c = "ssh $(cat ${config.age.secrets."cop3223c".path})";
        # radon-only: the ssh config for argon lives in this user file.
        argon = "ssh argon";
      };
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
          User = "root";
        };
      };
    };
  };
}
