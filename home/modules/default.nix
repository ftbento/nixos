{ config, pkgs, ... }: {
  imports = [
    ./nvim.nix
    ./appimage.nix
    ./fastfetch.nix
    ./fish.nix
    ./git.nix
    ./kitty.nix
    ./yazi.nix
  ];
}
