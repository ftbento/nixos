{ config, lib, pkgs, ... }: {
  options.workstation.fuzzel = {
    enable = lib.mkEnableOption "fuzzel launcher";
  };

  config = lib.mkIf config.workstation.fuzzel.enable {
    environment.systemPackages = with pkgs; [
      fuzzel
    ];

    home-manager.users.benjidev.programs.fuzzel = {
      enable = true;
      settings = {
        main = {
          # Anchor Fuzzel to the bottom of the screen
          anchor = "bottom";

          y-margin = 20;

          # Standard clean launcher settings
          lines = 8;
          width = 32;
          horizontal-pad = 24;
          vertical-pad = 18;
          inner-pad = 12;
          line-height = 26;
          image-size-ratio = 0.5;
          prompt = "❯ ";
        };

        border = {
          width = 2;
          radius = 16;
        };
      };
    };
  };
}
