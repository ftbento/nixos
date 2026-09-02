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

  programs.qylock = {
    enable = true;
    theme = "nothing";
    sddm.enable = true;        # install + activate the SDDM theme
    quickshell.enable = false; # keep ambxst as the after-login lock screen
  };

  # Host-specific system packages
  environment.systemPackages = with pkgs; [
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
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

  # Host-specific monitor layout + workspace keybinds. Generic Hyprland settings
  # (binds, animations, etc.) live in profiles/desktop.nix.
  home-manager.users.benjidev.wayland.windowManager.hyprland.settings = {
    monitor = [
      ", preferred, auto, 1"
      "DP-5, 2560x1440@164.96, 0x0, 1"
      "HDMI-A-5, 1920x1080@60, 320x-1080, 1, transform, 2"
    ];

    workspace = [
      "1, monitor:DP-5"
      "2, monitor:DP-5"
      "3, monitor:DP-5"
      "4, monitor:DP-5"
      "5, monitor:DP-5"
      "6, monitor:HDMI-A-5"
      "7, monitor:HDMI-A-5"
      "8, monitor:HDMI-A-5"
      "9, monitor:HDMI-A-5"
      "10, monitor:HDMI-A-5"
    ];

    exec-once = [
      "xrandr --output DP-5 --primary"
      "steam -silent"
    ];

    bind = [
      "$mainMod, 1, workspace, 6"
      "$mainMod, 1, workspace, 1"
      "$mainMod, 2, workspace, 7"
      "$mainMod, 2, workspace, 2"
      "$mainMod, 3, workspace, 8"
      "$mainMod, 3, workspace, 3"
      "$mainMod, 4, workspace, 9"
      "$mainMod, 4, workspace, 4"
      "$mainMod, 5, workspace, 10"
      "$mainMod, 5, workspace, 5"
      "$mainMod SHIFT, 1, movetoworkspace, 1"
      "$mainMod SHIFT, 2, movetoworkspace, 2"
      "$mainMod SHIFT, 3, movetoworkspace, 3"
      "$mainMod SHIFT, 4, movetoworkspace, 4"
      "$mainMod SHIFT, 5, movetoworkspace, 5"
    ];
  };

  # System state version - DO NOT CHANGE this after first install
  system.stateVersion = "26.05";
}
