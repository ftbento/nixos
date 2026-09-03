{ pkgs, ... }: {
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
  };

  environment.systemPackages = with pkgs; [
    kitty
    hyprcursor
    hyprutils
    hyprwayland-scanner
    hyprshot
    wlogout
    btop
    cliphist
    wl-clipboard
    xrandr
  ];
}
