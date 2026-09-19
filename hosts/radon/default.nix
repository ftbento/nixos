# radon — personal workstation

{ config, lib, pkgs, inputs, users, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/core.nix
    ../../profiles/desktop.nix
    ../../modules/core/gpu/amd.nix  # host-specific GPU driver
  ];

  networking.hostName = "radon";

  # Auto-mount data drives (mounted by systemd at boot; nofail = won't block boot if absent)
  fileSystems."/mnt/games" = {
    device = "/dev/disk/by-uuid/9f0c7685-7d74-496d-94a1-f5fd7e6e21db"; # sdb1 ext4 "Games"
    fsType = "ext4";
    options = [ "nofail" "noatime" ];
  };

  fileSystems."/mnt/windows" = {
    device = "/dev/disk/by-uuid/5652DA3D52DA2213"; # sda3 ntfs "Basic data partition"
    fsType = "ntfs3";
    options = [ "nofail" "x-systemd.device-timeout=5" "ro" "uid=1000" "gid=100" "fmask=0111" "dmask=000" ];
  };

  fileSystems."/mnt/zorin" = {
    device = "/dev/disk/by-uuid/3d97e9d6-17f8-46b9-ab8c-c9f5acf2a2d2"; # nvme0n1p1 ext4 (Zorin OS)
    fsType = "ext4";
    options = [ "nofail" "ro" "noatime" ]; # read-only so NixOS never writes to Zorin's root
  };

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;

  # Host-specific system packages
  environment.systemPackages = with pkgs; [
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
    inputs.opencode.packages.${pkgs.stdenv.hostPlatform.system}.default
    vscode
  ];

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      grub = {
        enable = true;
        useOSProber = true;
        devices = [ "nodev" ];
        efiSupport = true;

        theme = ./tsushima;
        configurationLimit = 5;  # max 5 versions in bootloader
      };
    };
  };

  # Host-specific monitor/workspace layout lives in the Lua config now
  # (hyprland.lua requires host.lua). Keybinds are gone from here — nothing to
  # bind workspace numbers, Super+Shift+scroll switches workspaces.
  home-manager.users.benjidev.xdg.configFile."hypr/host.lua".source = ./hyprland-host.lua;

  # System state version - DO NOT CHANGE this after first install
  system.stateVersion = "26.05";
}
