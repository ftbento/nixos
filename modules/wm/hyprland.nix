{ pkgs, inputs, ... }:
let
  unstable = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in {
  # Pin Hyprland from nixpkgs-unstable: nixos-26.05 stable only ships 0.55.x,
  # which has a bug where closing a keyboard-grabbing layer-shell surface
  # (Noctalia launcher/control center) with follow_mouse != 1 never restores
  # keyboard focus to the window underneath (hyprwm/Hyprland#14285). Fixed
  # upstream in 0.56.0, and the Lua config needs >= 0.55 anyway.
  programs.hyprland = {
    enable = true;
    package = unstable.hyprland;
    xwayland.enable = true;
    withUWSM = true;
  };

  # Idle handling: hypridle locks after 10 min idle (hyprlock), turns the
  # screens off at 30 min, then suspends. hyprlock is the session lock screen
  # for Super+Escape AND the Noctalia session-menu Lock action. Locking never
  # kills the session; suspend/resume returns to the running desktop.
  # The timers live in modules/wm/hypridle.conf (installed by the desktop
  # profile's home-manager block).
  services.hypridle = {
    enable = true;
    package = unstable.hypridle; # match Hyprland version
  };

  environment.systemPackages = with pkgs; [
    kitty
    hyprcursor
    hyprutils
    hyprwayland-scanner
    gpu-screen-recorder
    wlogout
    btop
    xrandr
  ] ++ [ unstable.hyprlock ];
}
