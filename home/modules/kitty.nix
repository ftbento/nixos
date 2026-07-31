{ config, lib, ... }: let
  cfg = config.home.kitty;
in {
  options.home.kitty = {
    enable = lib.mkEnableOption "kitty terminal configuration";
    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = {};
      description = "Kitty terminal settings";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.kitty = lib.mkForce {
      enable = true;
      settings = cfg.settings;
    };
  };
}
