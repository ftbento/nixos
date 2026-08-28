{ config, pkgs, ... }: {
  imports = [
    ./flatpak.nix
    ./fuzzel.nix
    ./gaming.nix
    ./virtualization.nix
  ];
}
