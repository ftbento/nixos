{ config, pkgs, ... }: {
  imports = [
    ./core
    ./software
    ./tweaks
    ./wm/hyprland.nix
    ./de/gnome.nix
    ./shell/ambxst.nix
  ];
}
