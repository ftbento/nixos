{ config, pkgs, ... }: {
  imports = [
    ./core
    ./software
    ./tweaks
    ./wm/gnome.nix
  ];
}
