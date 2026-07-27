{ config, pkgs, ... }: {
  imports = [
    ./fish.nix
    ./git.nix
    ./kitty.nix
    ./fastfetch
    ./man.nix
  ];
}
