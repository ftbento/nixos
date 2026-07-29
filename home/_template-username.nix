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

  # Home Manager configuration
  home-manager.users.${username} = {
    imports = [ ../modules/home ];

    home = {
      username = username;
      homeDirectory = "/home/${username}";
      stateVersion = "25.11";
      packages = with pkgs; [

      ];
    };

    # Enable shared modules and set per-user options
    # myUser.fish = {
    #   enable = true;
    #   shellAliases = {
    #     # ...
    #   };
    # };
    #
    # myUser.git = {
    #   enable = true;
    #   userName = "<git user name>";
    #   userEmail = "<git user email>";
    # };
    #
    # myUser.kitty = {
    #   enable = true;
    #   settings = {
    #     # ...
    #   };
    # };
    #
    # myUser.fastfetch = {
    #   enable = true;
    # };
  };
}
