{ config, pkgs, lib, inputs, ... }:

let
  cfg = config.workstation.ambxst;
in
{
  imports = [
    inputs.ambxst.nixosModules.default
  ];

  options.workstation.ambxst = {
    enable = lib.mkEnableOption "ambxst shell configuration";

    user = lib.mkOption {
      type = lib.types.str;
      description = "The primary user to assign hardware groups and packages to.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Pull in Ambxst's own NixOS module: it registers the shell package plus the
    # required fonts (Roboto, Phosphor Icons, ...) via fonts.packages and
    # enables upower/power-profiles-daemon/networkmanager by default.
    programs.ambxst.enable = lib.mkForce true;

    fonts.fontconfig.enable = true;

    environment.systemPackages = [
      pkgs.gpu-screen-recorder
    ];

    networking.networkmanager.enable = true;
    hardware.bluetooth.enable = true;
    services.blueman.enable = true;
    hardware.i2c.enable = true;
    services.power-profiles-daemon.enable = true;

    users.users.${cfg.user}.extraGroups = [
      "networkmanager"
      "video"
      "i2c"
    ];
  };
}