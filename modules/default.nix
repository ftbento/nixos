{ config, pkgs, ... }: {
  imports = [
    ./core
    ./software
    ./tweaks
    ./de/gnome.nix
  ];
}
