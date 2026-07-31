{ config, pkgs, lib, ... }: let
    cfg = config.home.fish;
  in 
  {
  options.home.fish = {
    enable = lib.mkEnableOption "fish shell configuration";
    generateCompletions = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Generate fish completions automatically";
    };
    shellAliases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Shell aliases for fish";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.fish = {
      enable = true;
      generateCompletions = cfg.generateCompletions;
      interactiveShellInit = ''
        set fish_greeting # Disable greeting
      '';
      plugins = [
        { name = "grc"; src = pkgs.fishPlugins.grc.src; }
      ];
      shellAliases = cfg.shellAliases;
    };
  };
}
