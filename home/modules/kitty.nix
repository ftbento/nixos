{ config, lib, ... }: {
  options.myUser.kitty = {
    enable = lib.mkEnableOption "kitty terminal configuration";
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Kitty terminal settings";
    };
  };

  config = let
    cfg = config.myUser.kitty;
  in lib.mkIf cfg.enable {
    programs.kitty = lib.mkForce {
      enable = true;
      settings = cfg.settings;
    };
  };
}
