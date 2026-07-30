{ config, pkgs, ... }: {
  imports = [
    ./fish.nix
    ./git.nix
    ./hyprland.nix
    ./kitty.nix
    ./fastfetch
    ./waybar.nix
    ./wofi.nix
  ];
}
