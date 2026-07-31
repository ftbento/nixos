{ config, pkgs, inputs, ... }: let
  username = "<username>";
in {
  # System-level user creation
  programs.<shell>.enable = true;
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.<shell>;
  };

  age.identityPaths = [ "/home/${username}/.ssh/id_ed25519" ];
  age.secrets."SECRET_NAME" = {
    file = ../secrets/SECRET_NAME.age;
    owner = username;
  };

  # SDDM/accountsservice avatar for this user — place image at ../config/<username>.png
  # systemd.tmpfiles.rules = [
  #   "f+ /var/lib/AccountsService/users/${username} 0600 root root - [User]\\nIcon=/var/lib/AccountsService/icons/${username}\\n"
  #   "L+ /var/lib/AccountsService/icons/${username} - - - - ${../config}/${username}.png"
  # ];

  # Home Manager configuration
  home-manager.users.${username} = {
    imports = [ ./modules ];

    home = {
      username = username;
      homeDirectory = "/home/${username}";
      stateVersion = "26.05";
      packages = with pkgs; [

      ];
    };

    # Enable shared modules and set per-user options
    # home.fastfetch.enable = true;

    # home.fish = {
    #   enable = true;
    #   shellAliases = {
    #  
    #   };
    # };

    # home.git = {
    #   enable = true;
    #   userName = "<username>";
    #   userEmail = "<email>>";
    # };

    # home.kitty = {
    #   enable = true;
    #   settings = {
    #
    #   };
    # };
  };
}
