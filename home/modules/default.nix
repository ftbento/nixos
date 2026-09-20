{ config, pkgs, ... }: {
  imports = [
    ./fastfetch.nix
    ./fish.nix
    ./git.nix
    ./kitty.nix
    ./yazi.nix
  ];
}
