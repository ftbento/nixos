# radon — personal workstation

{ config, pkgs, inputs, users, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/core.nix
    ../../profiles/desktop.nix
    ../../modules/core/gpu/amd.nix  # host-specific GPU driver
    users.benjidev                  # primary user account (home/benjidev.nix)
  ];

  networking.hostName = "radon";
  workstation.user = "benjidev";

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

  # Host-specific display state that the desktop profile deliberately keeps out
  # of the shared layer: Hyprland monitor/workspace layout lives in host.lua and
#   Noctalia wallpapers/widgets live here too. (The lock screen is hyprlock
  #   everywhere — hyprland.lua Super+Escape + Noctalia session Lock action.)
  home-manager.users.${config.workstation.user} = {
    xdg.configFile."hypr/host.lua".source = ./hyprland-host.lua;

    programs.noctalia.settings = {
      # Pixelfed default.jpg on every output.
      wallpaper = {
        enabled = true;
        default.path = "/home/benjidev/Pictures/Wallpapers/default.jpg";
        monitors."DP-5".path     = "/home/benjidev/Pictures/Wallpapers/default.jpg";
        monitors."HDMI-A-5".path = "/home/benjidev/Pictures/Wallpapers/default.jpg";
      };

      # Desktop widgets configured in the GUI (audio visualizer, clock,
      # weather) on DP-5.
      desktop_widgets = {
        schema_version = 2;
        widget_order = [
          "desktop-widget-0000000000000001"
          "desktop-widget-0000000000000002"
          "desktop-widget-0000000000000004"
        ];
        grid = {
          cell_size = 16;
          major_interval = 4;
          visible = true;
        };
        widget = {
          "desktop-widget-0000000000000001" = {
            box_height = 80.0;
            box_width = 2560.0;
            cx = 1280.0;
            cy = 72.0;
            flip_y = true;
            output = "DP-5";
            placement_height = 1440.0;
            placement_width = 2560.0;
            rotation = 0.0;
            type = "audio_visualizer";
            settings = {
              background = false;
              bands = 100;
              centered = false;
              mirrored = true;
              reversed = false;
              show_when_idle = false;
            };
          };
          "desktop-widget-0000000000000002" = {
            box_height = 240.0;
            box_width = 304.0;
            cx = 1864.0;
            cy = 320.0;
            output = "DP-5";
            placement_height = 1440.0;
            placement_width = 2560.0;
            rotation = 0.0;
            type = "clock";
            settings = {
              background = false;
              clock_style = "analog";
              color = "on_surface";
              font_family = "";
              shadow = true;
              timezone = "America/New_York";
            };
          };
          "desktop-widget-0000000000000004" = {
            box_height = 64.0;
            box_width = 160.0;
            cx = 1872.0;
            cy = 464.0;
            output = "DP-5";
            placement_height = 1440.0;
            placement_width = 2560.0;
            rotation = 0.0;
            type = "weather";
            settings = {
              background = false;
              shadow = true;
              show_forecast = false;
            };
          };
        };
      };
    };
  };

  # System state version - DO NOT CHANGE this after first install
  system.stateVersion = "26.05";
}