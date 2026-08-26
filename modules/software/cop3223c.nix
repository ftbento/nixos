{ config, lib, pkgs, ... }: let
  cfg = config.workstation.cop3223c;
in {
  options.workstation.cop3223c = {
    enable = lib.mkEnableOption "COP 3223C – C development environment";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      gcc
      gnumake
      gdb
      valgrind
      openssh
    ];
  };
}
