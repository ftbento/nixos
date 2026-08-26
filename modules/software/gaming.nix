{ config, lib, pkgs, ... }: let
  cfg = config.workstation.gaming;
in {
  options.workstation.gaming = {
    enable = lib.mkEnableOption "Linux gaming (Steam, GameMode, Gamescope, MangoHud)";
  };

  config = lib.mkIf cfg.enable {
    # --- Steam (with gaming optimisations) ---
    programs.steam = {
      enable = true;
      gamescopeSession.enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      # GE-Proton for better game compatibility
      extraCompatPackages = [ pkgs.proton-ge-bin ];
      # Needed inside the Steam FHS env so MangoHud/GameMode work in games
      extraPackages = with pkgs; [ mangohud gamemode ];
      protontricks.enable = true;
      # extest.enable = true;
    };

    # --- Feral GameMode (on-demand performance) ---
    programs.gamemode = {
      enable = true;
      settings = {
        general = {
          renice = 10;
          softrealtime = "auto";
          inhibit_screensaver = 1;
        };
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
          amd_performance_level = "high";
        };
        custom = {
          start = "${pkgs.libnotify}/bin/notify-send 'GameMode started'";
          end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended'";
        };
      };
    };

    # --- Gamescope (micro-compositor for games) ---
    programs.gamescope = {
      enable = true;
      capSysNice = true;
    };

    # --- MangoHud (perf overlay, themed by Stylix) ---
    home-manager.users.benjidev.programs.mangohud = {
      enable = true;
      enableSessionWide = true;
      settings = {
        fps_limit = 0;
        vsync = 0;
        fps = true;
        frame_timing = true;
        cpu_stats = true;
        cpu_temp = true;
        gpu_stats = true;
        gpu_temp = true;
        vram = true;
        ram = true;
        position = "top-left";
        toggle_hud = "Shift_R+F12";
      };
    };

    # Kernel tweaks for gaming
    boot.kernel.sysctl = {
      # Some games (modded/high-mapcount) need more mmaps
      "vm.max_map_count" = 2147483642;
      "fs.inotify.max_user_watches" = 524288;
      "fs.inotify.max_user_instances" = 524288;
    };
  };
}
