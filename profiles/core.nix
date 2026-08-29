# Barebones configuration shared by every device (desktops and headless servers).
# Keep this minimal: only infrastructure that all machines truly need.
# Desktop-specific config lives in profiles/desktop.nix; headless-server config
# is unique per host and lives directly in the host file (e.g. hosts/argon).

{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    ../modules/core/core.nix         # timezone, locale, xkb layout
    ../modules/core/nix.nix          # flakes + nix-command
    ../modules/core/agenix.nix       # secrets infrastructure
    ../modules/core/home-manager.nix # home-manager base module
    ../modules/core/nh.nix           # nh (nix helper)
    ../modules/core/tailscale.nix    # tailscale network
    ../modules/tweaks/man.nix        # slim man page generation
  ];

  nixpkgs.config.allowUnfree = true;
}
