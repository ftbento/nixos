{ config, lib, ... }:
{
  options.home.git.enable = lib.mkEnableOption "git configuration";

  config = lib.mkIf config.home.git.enable {
    programs.git = {
      enable = true;
      settings.user = {
        name = "ftbento";
        email = "ftbento@users.noreply.github.com";
      };
    };
  };
}
