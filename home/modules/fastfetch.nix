{ config, lib, ... }:
{
  options.home.fastfetch.enable = lib.mkEnableOption "fastfetch configuration";

  config = lib.mkIf config.home.fastfetch.enable {
    programs.fastfetch = {
      enable = true;
      settings = {
        display = {
          separator = " ";
          color = {
            # Base16 color 9 (base09) from the Stylix scheme, so the border
            # inherits the active theme and updates when it changes.
            keys = config.lib.stylix.colors.withHashtag.base05;
          };
        };
        modules = [
             { type = "custom"; key = "╭────────╮"; }
              { type = "title"; key = "│ {#35}  nme {#keys}│"; keyWidth = 12; format = "{user-name}"; }
              { type = "title"; key = "│ {#35}󰌢  hst {#keys}│"; keyWidth = 12; format = "{host-name}"; }
             { type = "uptime"; key = "│ {#34}󱎫  upt {#keys}│"; keyWidth = 12; }
                 { type = "os"; key = "│ {#33}  dst {#keys}│"; keyWidth = 12; }
             { type = "kernel"; key = "│ {#33}󰌽  ker {#keys}│"; keyWidth = 12; }
                 { type = "wm"; key = "│ {#33}󰧨  twm {#keys}│"; keyWidth = 12; }
           { type = "terminal"; key = "│ {#31}  trm {#keys}│"; keyWidth = 12; }
              { type = "shell"; key = "│ {#31}󰞷  shl {#keys}│"; keyWidth = 12; }
             { type = "custom"; key = "├────────┤"; }
             { type = "colors"; key = "│ {#37}󰏘  clr {#keys}│"; keyWidth = 12; symbol = "circle"; }
             { type = "custom"; key = "╰────────╯"; }
        ];
      };
    };
  };
}
