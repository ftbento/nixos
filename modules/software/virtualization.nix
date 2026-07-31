{ config, lib, ... }: let
    cfg = config.workstation.virtualization;
  in {
  options.workstation.virtualization.enable = lib.mkEnableOption "QEMU/KVM virtualization";

  config = lib.mkIf cfg.enable {
    virtualisation.libvirtd.enable = true;
    programs.virt-manager.enable = true;
    users.users.benjidev.extraGroups = [ "libvirtd" ];
  };
}
