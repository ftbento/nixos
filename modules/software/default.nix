{ config, pkgs, ... }: {
  imports = [
    ./cop3223c.nix
    ./flatpak.nix
    ./fuzzel.nix
    ./gaming.nix
    ./virtualization.nix
  ];
}
