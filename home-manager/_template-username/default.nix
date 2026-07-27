{ config, pkgs, ... }: {
  # System-level user creation
  programs.<shell>.enable = true; # allows access to <shell> outside of home-manager for below
  users.users.<username> = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" ];
    shell = pkgs.<shell>; # primary global shell for this user
  };

  # Home Manager configuration
  home-manager.users.<username> = { config, pkgs, inputs, ... }: {
    imports = [
      ./modules
    ];
    
    home = {
      username = "<username>";
      homeDirectory = "/home/<username>";
      stateVersion = "25.11";
      packages = with pkgs; [
        
      ];
    };

    # age.secrets.SECRET_NAME.file = ../../../secrets/SECRET_NAME.age;
  };
}
