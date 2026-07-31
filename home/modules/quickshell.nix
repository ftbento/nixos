{ config, pkgs, lib, ... }: let
  cfg = config.home.quickshell;
in {
  options.home.quickshell = {
    enable = lib.mkEnableOption "Quickshell desktop shell";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      quickshell
      qt6.qtsvg
      qt6.qtdeclarative
      qt6.qtimageformats
      qt6.qtmultimedia
    ];
  };
}
