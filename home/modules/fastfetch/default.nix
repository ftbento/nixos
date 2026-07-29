{ config, lib, ... }: {
  options.myUser.fastfetch = {
    enable = lib.mkEnableOption "fastfetch configuration";
    modules = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "title"
        "separator"
        "os"
        "host"
        "kernel"
        "uptime"
        "packages"
        "shell"
        "display"
        "de"
        "wm"
        "cpu"
        "gpu"
        "memory"
        "swap"
        "disk"
        "localip"
        "colors"
      ];
      description = "Fastfetch modules to display";
    };
  };

  config = let
    cfg = config.myUser.fastfetch;
  in lib.mkIf cfg.enable {
    programs.fastfetch = {
      enable = true;
      settings = {
        logo = {
          type = "data";
          source = builtins.readFile ./ascii.txt;
          color = {
            "1" = "red";
            "2" = "blue";
          };
          padding = { right = 2; };
        };
        modules = cfg.modules;
      };
    };
  };
}
