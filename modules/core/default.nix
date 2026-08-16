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
    ./stylix.nix
    ./tailscale.nix
  ];

  fonts.fontconfig.enable = true;
}

# garbage collection implemented through nh