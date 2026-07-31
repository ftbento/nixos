{ config, lib, ... }: let
    cfg = config.home.fastfetch;
  in 
  {
  options.home.fastfetch = {
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

  # users, host, uptime, kernel, term, shell, cpu, gpu, memory, disk, network, colors

  config = lib.mkIf cfg.enable {
    programs.fastfetch = {
      enable = true;
      settings = {
        # logo = {
        #   type = "data";
        #   source = builtins.readFile ./ascii.txt;
        #   padding = { right = 2; };
        # };
        display = {
          separator = " ";
          color = {
            keys = "black"; # Sets the default border color (gray/black)
          };
        };
        modules = [
             { type = "custom"; key = "╭─────────╮"; }
              { type = "title"; key = "│ {#37}  nme  {#keys}│"; keyWidth = 12; format = "{user-name}"; }
               { type = "host"; key = "│ {#37}󰌢  hst  {#keys}│"; keyWidth = 12; format = "{host-name}"; }
             { type = "uptime"; key = "│ {#35}󱎫  upt  {#keys}│"; keyWidth = 12; }
                 { type = "os"; key = "│ {#35}  dst  {#keys}│"; keyWidth = 12; }
             { type = "kernel"; key = "│ {#33}󰌽  ker  {#keys}│"; keyWidth = 12; }
                 { type = "wm"; key = "│ {#33}󰧨  twm  {#keys}│"; keyWidth = 12; }
           { type = "terminal"; key = "│ {#31}  trm  {#keys}│"; keyWidth = 12; }
              { type = "shell"; key = "│ {#31}󰞷  shl  {#keys}│"; keyWidth = 12; }
             { type = "custom"; key = "├─────────┤"; }
             { type = "colors"; key = "│ {#39}󰏘  clr  {#keys}│"; keyWidth = 12; symbol = "circle"; }
             { type = "custom"; key = "╰─────────╯"; }
        ];
      };
    };
  };
}