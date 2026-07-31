{ config, lib, ... }: let
  cfg = config.home.yazi;
in {
  options.home.yazi = {
    enable = lib.mkEnableOption "Yazi file manager";
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {
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
      description = "Yazi configuration settings";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      settings = cfg.settings;
    };
  };
}
