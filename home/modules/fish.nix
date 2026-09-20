{ config, lib, pkgs, ... }:

# Starter aliases are baked in per-user here — generic ones only. Machine-
# specific aliases (e.g. an `argon` ssh alias that only makes sense on radon)
# go in `home.fish.extraAliases` for the user that has them. Use that same
# option for secret-dependent aliases that need a value from the NixOS scope
# (e.g. an agenix secret path), which is unavailable in HM scope.
let
  aliases = {
    nhswitch = "nh os switch ~/nixos";
    nhboot = "nh os boot  ~/nixos";
    nhtest = "nh os test ~/nixos";
    nhupdate = "nix flake update --flake ~/nixos && nh os switch  ~/nixos";
    nhclean = "nh clean all --keep-since 4d --keep 3";
    nhlist = "nixos-rebuild list-generations";
    ff = "fastfetch";
    ".." = "cd ..";
  };
in
{
  options.home.fish = {
    enable = lib.mkEnableOption "fish shell configuration";
    extraAliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Extra shell aliases added on top of the baked defaults";
    };
  };

  config = lib.mkIf config.home.fish.enable {
    programs.fish = {
      enable = true;
      generateCompletions = true;
      interactiveShellInit = lib.mkAfter ''
        set fish_greeting # Disable greeting
      '';
      plugins = [
        { name = "grc"; src = pkgs.fishPlugins.grc.src; }
      ];
      shellAliases = aliases // config.home.fish.extraAliases;
    };
  };
}
