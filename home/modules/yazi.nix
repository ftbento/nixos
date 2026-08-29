{ config, lib, ... }:
{
  options.home.yazi.enable = lib.mkEnableOption "Yazi file manager";

  config = lib.mkIf config.home.yazi.enable {
    programs.yazi = {
      enable = true;
      settings = {
        yazi = {
          ratio = [ 1 4 3 ];
          sort_by = "natural";
          sort_sensitive = true;
          sort_reverse = false;
          sort_dir_first = true;
          linemode = "none";
          show_hidden = true;
          show_symlink = true;
        };
      };
    };
  };
}
