{ config, pkgs, ... }: {
  imports = [
    ./fastfetch
    ./fish.nix
    ./git.nix
    ./kitty.nix
    ./yazi.nix
  ];
}
