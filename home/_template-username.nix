{ config, pkgs, lib, inputs, ... }: let
  username = "<username>";
in {
  # System-level user creation
  programs.<shell>.enable = true;
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.<shell>;
  };

  # secrets (agenix) — declare any secrets this user needs (see secret files in ../secrets)
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

  # Home Manager configuration.
  #
  # Concrete values for the shared modules below (fish aliases, git identity,
  # kitty settings, yazi/fastfetch) are baked into home/modules/* — just enable
  # them here, plus any per-user extras (e.g. secret-dependent aliases).
  home-manager.users.${username} = {
    imports = [ ./modules ];

    home = {
      username = username;
      homeDirectory = "/home/${username}";
      stateVersion = "26.05";
      packages = with pkgs; [

      ];
    };

    # home.fastfetch.enable = true;
    # home.yazi.enable = true;
    # home.git.enable = true;
    # home.kitty.enable = true;
    # home.fish = {
    #   enable = true;
    #   extraAliases = { };
    # };
  };
}
