{ pkgs, inputs, ... }: {
  # Pin Hyprland from nixpkgs-unstable: nixos-26.05 stable only ships 0.55.x,
  # which has a bug where closing a keyboard-grabbing layer-shell surface
  # (Noctalia launcher/control center) with follow_mouse != 1 never restores
  # keyboard focus to the window underneath (hyprwm/Hyprland#14285). Fixed
  # upstream in 0.56.0, and the Lua config needs >= 0.55 anyway.
  programs.hyprland = {
    enable = true;
    package = inputs.nixpkgs-unstable.legacyPackages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    xwayland.enable = true;
    withUWSM = true;
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
  ];
}
