# Reusable desktop persona. Import this on every interactive machine
# (radon, laptop, ...) to get the full desktop stack. Host-specific bits
# (GPU driver, monitors, keybinds, mountpoints) stay in the host file.

{ config, lib, pkgs, inputs, users, ... }:
{
  imports = [
    ../modules/core/graphics.nix      # OpenGL/Vulkan
    ../modules/core/pipewire.nix      # audio
    ../modules/core/bluetooth.nix     # BT + blueman
    ../modules/core/stylix.nix        # theming
    ../modules/core/systemd.nix       # don't restart display-manager on update
    ../modules/wm/hyprland.nix
    ../modules/wm/hyprlock.nix
    inputs.noctalia.nixosModules.default
    ../modules/software/gaming.nix
    ../modules/software/fuzzel.nix
    ../modules/software/flatpak.nix
    ../modules/software/rustdesk.nix
    ../modules/software/vpn.nix
    inputs.qylock.nixosModules.default
    users.benjidev
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
  users.users.benjidev.extraGroups = [ "video" "i2c" ];

  # SDDM login screen themed with the qylock Qt6 theme. The X server is only
  # enabled to host the greeter; the actual session is Hyprland/Wayland.
  # (SilentSDDM is disabled: it hard-depends on weston which crashes on amdgpu.)
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;

  programs.qylock = {
    enable = true;
    theme = "nothing";
    sddm.enable = true;        # install + activate the qylock SDDM login screen
    quickshell.enable = true;  # qylock-lock used as the after-login lock screen
  };

  # Desktop home-manager configuration for the primary user.
  home-manager.users.benjidev = {
    imports = [ inputs.noctalia.homeModules.default ];

    # Declarative Noctalia config (~/.config/noctalia/config.toml). Kept small —
    # everything not listed falls back to upstream defaults. setup_wizard_enabled
    # skips the first-run wizard; Catppuccin matches Stylix's catppuccin-mocha.
    # Radon uses Hyprland's scrolling layout, not Niri, which Noctalia supports
    # directly. qylock stays the lock screen (Super+Escape), so Noctalia's own
    # lockscreen is disabled.
    programs.noctalia = {
      enable = true;
      package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
      settings = {
        shell = {
          setup_wizard_enabled = false;
          telemetry_enabled = false;
          polkit_agent = true;
          clipboard_enabled = true;
        };
        theme = {
          mode = "dark";
          source = "builtin";
          builtin = "Catppuccin";
        };
        bar.main = {
          position = "top";
          start = [ "launcher" "workspaces" ];
          center = [ "clock" ];
          end = [ "tray" "notifications" "network" "volume" "control-center" "session" ];
        };
        lockscreen.enabled = false;
      };
    };

    # Hyprland uses hyprcursor; make sure the Bibata theme (set via stylix.cursor)
    # is also picked up by Hyprland instead of the default Hyprland logo cursor.
    home.pointerCursor.hyprcursor.enable = true;

    # Generic Hyprland settings. Monitors/keybinds stay in the host file so a
    # laptop can override the multi-monitor layout cleanly.
    wayland.windowManager.hyprland = {
      enable = true;
      package = null;
      configType = "hyprlang";
      systemd.enable = false; # UWSM handles systemd session integration

      settings = {
        "$terminal" = "kitty";
        "$mainMod" = "SUPER";

        exec-once = [
          "noctalia"
          "hyprctl setcursor Bibata-Modern-Classic 24"
          "wl-paste --type text --watch cliphist store"
          "wl-paste --type image --watch cliphist store"
        ];

        input = {
          kb_layout = "us";
          kb_options = "caps:super";
          sensitivity = -0.25;
          follow_mouse = 2; # pointer focus follows cursor, keyboard stays on last click
        };

        cursor = {
          no_hardware_cursors = true;
        };

        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          layout = "scrolling";
        };

        scrolling = {
          column_width = 1.0;
          fullscreen_on_one_column = true;
        };

        decoration = {
          rounding = 10;
          blur = {
            enabled = true;
            size = 4;
            passes = 2;
          };
        };

        animations = {
          enabled = true;

          bezier = [
            "easeOutCubic, 0.33, 1, 0.68, 1"
            "easeInOutCubic, 0.65, 0.05, 0.36, 1"
            "easeOutQuint, 0.23, 1, 0.32, 1"
            "snappy, 0.15, 0, 0.1, 1"
            "linear, 1, 1, 1, 1"
          ];

          animation = [
            "windows, 1, 7, easeOutQuint"
            "windowsOut, 1, 7, easeOutQuint, popin 80%"
            "border, 1, 10, easeOutCubic"
            "borderangle, 1, 8, easeInOutCubic"
            "fade, 1, 7, easeOutCubic"
            "workspaces, 1, 6, easeOutQuint"
            "windowsMove, 1, 7, easeOutQuint"
          ];
        };

        bind = [
          # Noctalia IPC: launcher, control center, settings, window switcher
          "$mainMod, Space, exec, noctalia msg panel-toggle launcher"
          "$mainMod, S, exec, noctalia msg panel-toggle control-center"
          "$mainMod, comma, exec, noctalia msg settings-toggle"
          "ALT, Tab, exec, noctalia msg window-switcher"
          # Media/volume/brightness go through Noctalia so its OSD & widgets track them
          "$mainMod, Q, killactive"
          "$mainMod, Return, exec, $terminal"
          "$mainMod, Escape, exec, qylock-lock"
          "$mainMod, A, exec, pwvucontrol"
          ", Print, exec, hyprshot -m region --clipboard-only"
          "$mainMod, Print, exec, hyprshot -m output --clipboard-only"
          "$mainMod SHIFT, Print, exec, hyprshot -m window --clipboard-only"
          "XF86AudioRaiseVolume, exec, noctalia msg volume-up"
          "XF86AudioLowerVolume, exec, noctalia msg volume-down"
          "XF86AudioMute, exec, noctalia msg volume-mute"
          "XF86MonBrightnessUp, exec, noctalia msg brightness-up"
          "XF86MonBrightnessDown, exec, noctalia msg brightness-down"
          "$mainMod, h, layoutmsg, focus l"
          "$mainMod, l, layoutmsg, focus r"
          "$mainMod, k, layoutmsg, focus u"
          "$mainMod, j, layoutmsg, focus d"
          "$mainMod, mouse_up, layoutmsg, move +col"
          "$mainMod, mouse_down, layoutmsg, move -col"
          "$mainMod SHIFT, h, layoutmsg, swapcol l"
          "$mainMod SHIFT, l, layoutmsg, swapcol r"
          "$mainMod SHIFT, k, layoutmsg, expel"
          "$mainMod SHIFT, j, layoutmsg, consume"
          "$mainMod CTRL, h, layoutmsg, colresize -conf"
          "$mainMod CTRL, l, layoutmsg, colresize +conf"
          "$mainMod CTRL, k, layoutmsg, colresize -0.05"
          "$mainMod CTRL, j, layoutmsg, colresize +0.05"
        ];

        bindm = [
          "$mainMod, mouse:272, movewindow"
          "$mainMod, mouse:273, resizewindow"
        ];

        # Blur behind Noctalia layer-shell surfaces (bar, panels, notifications, OSD)
        layerrule = [
          "blur, ^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$"
        ];

        # Float the Noctalia settings window like a dialog
        windowrule = [
          "float, class:^(dev\\.noctalia\\.Noctalia)$"
          "size 1080 920, class:^(dev\\.noctalia\\.Noctalia)$"
        ];
      };
    };

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
    "f+ /var/lib/AccountsService/users/benjidev 0600 root root - [User]\\nIcon=/var/lib/AccountsService/icons/benjidev\\n"
    "L+ /var/lib/AccountsService/icons/benjidev - - - - ${../config}/benjidev.png"
  ];
}
