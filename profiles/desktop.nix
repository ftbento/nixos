# Reusable desktop persona. Import this on every interactive machine
# (radon, laptop, ...) to get the full desktop stack. Host-specific bits
# (GPU driver, monitors, keybinds, mountpoints) stay in the host file.

{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    ../modules/core/graphics.nix      # OpenGL/Vulkan
    ../modules/core/pipewire.nix      # audio
    ../modules/core/bluetooth.nix     # BT + blueman
    ../modules/core/stylix.nix        # theming
    ../modules/core/systemd.nix       # don't restart display-manager on update
    ../modules/wm/hyprland.nix
    inputs.noctalia.nixosModules.default
    ../modules/software/gaming.nix
    ../modules/software/flatpak.nix
    ../modules/software/rustdesk.nix
    ../modules/software/vpn.nix
    inputs.qylock.nixosModules.default
  ];

  # Noctalia desktop shell (bar, launcher, lock screen, widgets). Recommended
  # services cover NetworkManager/Bluetooth/UPower/power-profiles-daemon; the
  # shell itself is launched from Hyprland's exec-once below. A config.toml is
  # generated via the Home Manager module so first boot skips the setup wizard.
  programs.noctalia = {
    enable = true;
    recommendedServices.enable = true;
  };

  # Explicitly require NetworkManager (VPN module + blueman depend on it); don't
  # rely on Noctalia's recommendedServices mkDefault keeping it enabled.
  networking.networkmanager.enable = true;

  # System groups the shell needs for hardware access.
  hardware.i2c.enable = true;
  users.users.${config.workstation.user}.extraGroups = [ "video" "i2c" ];

  # SDDM login screen themed with the qylock Qt6 theme. The X server is only
  # enabled to host the greeter; the actual session is Hyprland/Wayland.
  # (SilentSDDM is disabled: it hard-depends on weston which crashes on amdgpu.)
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;

  programs.qylock = {
    enable = true;
    theme = "nothing";
    sddm.enable = true;        # install + activate the qylock SDDM login screen
    # quickshell lock screen disabled: qylock's "nothing" theme can't unlock
    # under Quickshell (login gated behind isQuickshell) -> hyprlock is used
    # for the after-login lock screen instead.
    quickshell.enable = false;
  };

  # Desktop home-manager configuration for the primary user.
  home-manager.users.${config.workstation.user} = {
    imports = [ inputs.noctalia.homeModules.default ];

    # Declarative Noctalia config (~/.config/noctalia/config.toml). Everything
    # that was previously tweaked at runtime (bar layout, launcher, wallpaper,
    # theme, control-center tabs, desktop widgets, ...) now lives here so the
    # declarative file owns the shell. setup_wizard_enabled skips the first-run
    # wizard. hyprlock is the lock screen everywhere (Super+Escape bind AND the
    # session-menu Lock action), so Noctalia's own lockscreen is off.
    programs.noctalia = {
      enable = true;
      package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
      settings = {
        # Built-in GPU screen recorder (gpu-screen-recorder): powers the
        # `screen_recorder` control-center shortcut and plugin toggle/replay.
        plugins.enabled = [ "noctalia/screen_recorder" ];

        # Runtime-tuned battery threshold for the mouse battery.
        battery.device."/org/freedesktop/UPower/devices/battery_hidpp_battery_0".warning_threshold = 25;

        shell = {
          font_family = "JetBrainsMono NF";
          setup_wizard_enabled = false;
          telemetry_enabled = false;
          polkit_agent = true;
          clipboard_enabled = true;
          screenshot = {
            copy_to_clipboard = true;
            save_to_file = true;
          };
          launcher = {
            categories = false;
            compact = true;
            show_icons = true;
            show_app_origin_indicator = false;
            sort_by_usage = true;
          };
          panel = {
            launcher_placement = "floating";
            launcher_position = "center";
            clipboard_placement = "floating";
            clipboard_position = "center";
            control_center_placement = "attached";
            session_placement = "attached";
          };
          session = {
            grid_columns = 2;
            actions = [
              { action = "lock"; command = "hyprlock"; }
              { action = "suspend"; }
              { action = "hibernate"; }
              { action = "logout"; }
              { action = "reboot"; }
              { action = "shutdown"; }
            ];
          };
          screen_corners = {
            enabled = true;
            size = 35;
          };
        };

        # The bar is three separate capsule "bubbles" rather than one continuous
        # strip: transparent bar background, so only the capsule groups are
        # visible, spread across the full width via margin_ends = 0. layer stays
        # "top" (the default), so the bar is already hidden beneath fullscreen
        # apps. Layout: (notifications workspaces) | (control center) |
        # (tray) (volume battery session).
        bar.main = {
          position = "top";
          background_opacity = 0;
          margin_ends = 0;
          start  = [ "group:start" ];
          center = [ "group:center" ];
          end    = [ "group:end" "group:end2" ];
          capsule_group = [
            { id = "start";  members = [ "notifications" "workspaces" ]; padding = 12; }
            { id = "center"; members = [ "control-center" ]; padding = 12; }
            { id = "end";    members = [ "tray" ]; padding = 12; }
            { id = "end2";   members = [ "volume" "battery" "session" ]; padding = 12; }
          ];
        };
        widget.volume.show_label = false;
        # Center control-center widget: Nix logo instead of the Noctalia glyph,
        # tinted with the widget color like the other bar icons.
        widget."control-center" = {
          custom_image = "~/.config/noctalia/nix-snowflake.svg";
          custom_image_colorize = true;
        };
        widget.settings.enabled = false;

        control_center = {
          hidden_tabs = [ "monitor" "screen-time" ];
          sidebar_section = "none";
          shortcuts = [
            { type = "wifi"; }
            { type = "bluetooth"; }
            # Full plugin entry id (author/plugin:entry); "screen_recorder" alone
            # doesn't resolve to anything and the tile silently disappears.
            { type = "noctalia/screen_recorder:toggle"; }
            { type = "session"; }
          ];
          calendar = {
            show_events_card = true;
            show_week_numbers = false;
          };
        };
        calendar = {
          enabled = true;
          refresh_minutes = 15;
        };
        weather = {
          enabled = true;
          refresh_minutes = 30;
          unit = "celsius";
          effects = true;
        };
        location.auto_locate = true;
        notification.enable_daemon = true;
        osd.position = "bottom";
        system.monitor = {
          enabled = true;
          cpu_poll_seconds = 2.0;
          gpu_poll_seconds = 5.0;
          memory_poll_seconds = 2.0;
          network_poll_seconds = 3.0;
          disk_poll_seconds = 10.0;
        };

        # Theme colors derive from the runtime wallpaper (Oxocarbon palette).
        theme = {
          mode = "dark";
          source = "wallpaper";
          builtin = "Catppuccin";
          community_palette = "Oxocarbon";
        };

        # hyprlock is the lock screen everywhere (Super+Escape bind AND the
        # session-menu Lock action), so Noctalia's own lockscreen is off.
        lockscreen.enabled = false;
      };
    };

    # Hyprland uses hyprcursor; make sure the Bibata theme (set via stylix.cursor)
    # is also picked up by Hyprland instead of the default Hyprland logo cursor.
    home.pointerCursor.hyprcursor.enable = true;

    # Hyprland is fully configured through the Lua API (Hyprland >= 0.55 loads
    # hyprland.lua and never reads a .conf, so no hyprland.conf is generated).
    # The home-manager hyprland module is intentionally NOT enabled.
    # Desktop-wide settings live in modules/wm/hyprland.lua; the entry requires
    # a per-host host.lua (installed by each host that uses the desktop profile).
    xdg.configFile."hypr/hyprland.lua".source = ../modules/wm/hyprland.lua;
    xdg.configFile."hypr/hyprlock.conf".source = ../modules/wm/hyprlock.conf;
    xdg.configFile."hypr/hypridle.conf".source = ../modules/wm/hypridle.conf;
    xdg.configFile."noctalia/nix-snowflake.svg".source = ../config/nix-snowflake.svg;

    # Notifications — Noctalia provides the daemon (enable_daemon default true),
    # so swaync is intentionally not enabled here (both would fight over the
    # org.freedesktop.Notifications DBus name).

    # Audio visualizer — via HM so Stylix can theme it
    programs.cava.enable = true;

    # Desktop packages
    home.packages = with pkgs; [
      vesktop
      wlogout
      obsidian
      inputs.ytm-player.packages.${pkgs.stdenv.hostPlatform.system}.default
      nerd-fonts.jetbrains-mono
    ];
  };

  # sddm user account picture
  systemd.tmpfiles.rules = [
    "f+ /var/lib/AccountsService/users/${config.workstation.user} 0600 root root - [User]\\nIcon=/var/lib/AccountsService/icons/${config.workstation.user}\\n"
    "L+ /var/lib/AccountsService/icons/${config.workstation.user} - - - - ${../config}/${config.workstation.user}.png"
  ];
}
