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
    ../modules/shell/ambxst.nix
    ../modules/software/gaming.nix
    ../modules/software/fuzzel.nix
    ../modules/software/flatpak.nix
    inputs.qylock.nixosModules.default
    users.benjidev
  ];

  # ambxst needs to know which user to assign hardware groups to.
  workstation.ambxst.user = "benjidev";

  # SDDM login screen themed with the qylock Qt6 theme. The X server is only
  # enabled to host the greeter; the actual session is Hyprland/Wayland.
  # (SilentSDDM is disabled: it hard-depends on weston which crashes on amdgpu.)
  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;

  programs.qylock = {
    enable = true;
    theme = "nothing";
    sddm.enable = true;        # install + activate the SDDM theme
    quickshell.enable = false; # keep ambxst as the after-login lock screen
  };

  # Desktop home-manager configuration for the primary user.
  home-manager.users.benjidev = {
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
          "ambxst"
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
          "$mainMod, D, exec, ambxst run launcher"
          "$mainMod, V, exec, ambxst run clipboard"
          "$mainMod, Q, killactive"
          "$mainMod, Return, exec, $terminal"
          "$mainMod, Escape, exec, ambxst lock"
          ", Print, exec, hyprshot -m region --clipboard-only"
          "$mainMod, Print, exec, hyprshot -m output --clipboard-only"
          "$mainMod SHIFT, Print, exec, hyprshot -m window --clipboard-only"
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
      };
    };

    # Notifications
    services.swaync.enable = true;

    # Audio visualizer — via HM so Stylix can theme it
    programs.cava.enable = true;

    # Desktop packages
    home.packages = with pkgs; [
      vesktop
      wlogout
      obsidian
      inputs.spotatui.packages.${pkgs.stdenv.hostPlatform.system}.default
      nerd-fonts.jetbrains-mono
    ];
  };

  # sddm user account picture
  systemd.tmpfiles.rules = [
    "f+ /var/lib/AccountsService/users/benjidev 0600 root root - [User]\\nIcon=/var/lib/AccountsService/icons/benjidev\\n"
    "L+ /var/lib/AccountsService/icons/benjidev - - - - ${../config}/benjidev.png"
  ];
}
