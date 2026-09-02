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

  # secrets (agenix)
  age.identityPaths = [ "/home/${username}/.ssh/id_ed25519" ];
  age.secrets."github-ftbento" = {
    file = ../secrets/github-ftbento.age;
    owner = username;
  };

  # Home Manager configuration — shared user profile. Desktop-specific bits
  # (Hyprland, swaync, wallpaper, desktop apps) live in profiles/desktop.nix.
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
        opencode
        yt-dlp
        grc
        playerctl
        jq
      ];
    };

    programs.btop.enable = true;

    # Shared user modules with config baked in. Only enable + per-user overrides.
    home.fastfetch.enable = true;
    home.yazi.enable = true;
    home.git.enable = true;
    home.kitty.enable = true;
    home.fish = {
      enable = true;
      extraAliases = {
        # Needs the decrypted agenix path, which is only available in NixOS scope.
        cop3223c = "ssh $(cat ${config.age.secrets."cop3223c".path})";
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
          User = "benjidev";
        };
      };
    };
  };
}
