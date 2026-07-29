{ config, lib, ... }: {
  options.myUser.git = {
    enable = lib.mkEnableOption "git configuration";
    userName = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Git user name";
    };
    userEmail = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Git user email";
    };
  };

  config = let
    cfg = config.myUser.git;
  in lib.mkIf cfg.enable {
    programs.git = {
      enable = true;
      settings = {
        user = {
          name = cfg.userName;
          email = cfg.userEmail;
        };
      };
    };
  };
}
