# radon — personal workstation

{ config, lib, pkgs, inputs, users, ... }:

let
in
{
  imports = [
    ./hardware-configuration.nix
    ../../profiles/core.nix
    ../../profiles/desktop.nix
    ../../modules/core/gpu/amd.nix  # host-specific GPU driver
    ../../modules/software/prismlauncher.nix  # Prism Launcher (GTNH single-player)
    users.benjidev                  # primary user account (home/benjidev.nix)
  ];

  networking.hostName = "radon";
  workstation.user = "benjidev";

  # --- Static LAN IP on ethernet -------------------------------------------
  # radon's stable LAN address: 10.8.90.228. NetworkManager is already
  # enabled by the desktop profile, so the profile is declared the NM way.
  # The DHCP wifi (wlo1) is left completely alone as an ignored failover;
  # `autoconnect-priority` makes this wired profile win over the auto-created
  # "Wired connection 1" NM keeps around.
  networking.networkmanager.ensureProfiles.profiles.wired-enp8s0 = {
    connection = {
      id = "wired-enp8s0";
      type = "ethernet";
      interface-name = "enp8s0";
      autoconnect = true;
      autoconnect-priority = 100;
    };
    ipv4 = {
      method = "manual";
      address1 = "10.8.90.228/24,10.8.90.1";
      dns = "1.1.1.1;8.8.8.8;";
      dns-search = "";
      route-metric = 100;
    };
    ipv6 = {
      method = "auto";
      addr-gen-mode = "stable-privacy";
      dns-search = "";
    };
  };


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

  # Run AppImages directly via binfmt_misc
  programs.appimage = {
    enable = true;
    binfmt = true;
  };

  # Run dynamically-linked, non-Nix binaries (e.g. prebuilt game servers/tools)
  programs.nix-ld.enable = true;

  # Host-specific system packages
  environment.systemPackages = with pkgs; [
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default
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
    # tmux is opted in per-host rather than from the shared user profile
    # (home/benjidev.nix), so it stays off on other machines unless their host
    # file imports home/modules/tmux.nix and sets home.tmux.enable too.
    imports = [
      ../../home/modules/tmux.nix
      ../../home/modules/lazyvim.nix
    ];
    home.tmux.enable = true;

    # LazyVim replaces the simple shared nvim config on this host.
    home.nvim.enable = false;
    home.lazyvim.enable = true;

    # Stylix's neovim theme injects `require('mini.base16')` into init.lua,
    # which runs before Home Manager's packdir plugins are on the runtimepath,
    # so it fails. Disable stylix's neovim target for now; LazyVim brings its
    # own colorscheme (catppuccin).
    stylix.targets.neovim.enable = false;

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