{ config, pkgs, ... }: {
  imports = [
    ./fastfetch.nix
    ./fish.nix
    ./git.nix
    ./kitty.nix
    ./opencode.nix
    ./yazi.nix
  ];
}
