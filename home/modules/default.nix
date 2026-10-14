{ config, pkgs, ... }: {
  imports = [
    ./appimage.nix
    ./fastfetch.nix
    ./fish.nix
    ./git.nix
    ./kitty.nix
    ./yazi.nix
  ];
}
