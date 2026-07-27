{ config, pkgs, ... }: {
  imports = [
    ./core
    ./wm/gnome.nix
    ./software
  ];
}
