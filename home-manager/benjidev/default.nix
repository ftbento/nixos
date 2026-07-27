{ config, pkgs, inputs, ... }: {
  # System-level user creation
  programs.fish.enable = true; # allows access to fish outside of home-manager for below
  users.users.benjidev = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.fish; # primary global shell for this user
  };

  # Home Manager configuration
  home-manager.users.benjidev = { config, pkgs, ... }: {
    imports = [
      ./modules
    ];
    
    home = {
      username = "benjidev";
      homeDirectory = "/home/benjidev";
      stateVersion = "25.11";
      packages = with pkgs; [
        # Desktop Apps
        # obsidian
        # vesktop

        # CLI
        kitty
        grc
        # ffmpeg
        # htop
        # playerctl
        # ripgrep
        # yt-dlp
      ];
    };

    age.secrets."github-ssh-key" = {
      file = ../../../secrets/github-ssh-key.age;
    };
    # SSH configuration with agenix for GitHub
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
