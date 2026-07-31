{ config, pkgs, ... }: {
  imports = [
    ./flatpak.nix
    ./steam.nix
    ./virtualization.nix
  ];
}
