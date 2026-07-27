{ config, pkgs, ... }: {
  imports = [
    ./bluetooth.nix
    ./core.nix
    ./graphics.nix
    ./home-manager.nix
    ./networking.nix
    ./nix.nix
    ./pipewire.nix
    ./nh.nix
    ./agenix.nix
    ./systemd.nix
    ./boot/grub.nix
  ];
}

# garbage collection implemented through nh