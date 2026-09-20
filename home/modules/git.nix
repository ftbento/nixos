{ config, lib, ... }:
{
  options.home.git = {
    enable = lib.mkEnableOption "git configuration";
    userName = lib.mkOption {
      type = lib.types.str;
      default = "ftbento";
      description = "Git user name";
    };
    userEmail = lib.mkOption {
      type = lib.types.str;
      default = "ftbento@users.noreply.github.com";
      description = "Git user email";
    };
  };

  config = lib.mkIf config.home.git.enable {
    programs.git = {
      enable = true;
      settings.user = {
        name = config.home.git.userName;
        email = config.home.git.userEmail;
      };
    };
  };
}