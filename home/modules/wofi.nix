{ config, lib, pkgs, ... }: {
  options.myUser.wofi = {
    enable = lib.mkEnableOption "Wofi configuration";
  };

  config = lib.mkIf config.myUser.wofi.enable {
    home.packages = with pkgs; [ wofi ];
  };
}
