{ config, pkgs, ... }: {
  imports = [
    ./core
    ./software
    ./tweaks
    ./wm/hyprland.nix
    ./wm/hyprlock.nix
    ./de/gnome.nix
    ./shell/ambxst.nix
  ];
}
