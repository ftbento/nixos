{ config, pkgs, inputs, ... }: {
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  stylix = {
    enable = true;

    # Color scheme. Any tinted-theming (base16) scheme can be used, see
    # https://github.com/tinted-theming/schemes for the full list.
    base16Scheme = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
    polarity = "dark";

    # Alternative: derive colors from a wallpaper image instead of base16Scheme.
    # Uncomment the line below (and optionally remove base16Scheme above):
    # image = ../../wallpapers/wallpaper.png;

    # Translucent terminal background (applies to kitty, etc.)
    opacity.terminal = 0.5;

    fonts = {
      monospace = {
        package = pkgs.nerd-fonts.jetbrains-mono;
        name = "JetBrainsMono Nerd Font";
      };
    };

    # Match the Hyprland cursor (hyprctl setcursor Bibata-Modern-Classic 24)
    # so GTK apps (and Waybar) can resolve hand2/arrow cursors.
    cursor = {
      name = "Bibata-Modern-Classic";
      package = pkgs.bibata-cursors;
      size = 24;
    };

    targets = {
      # Keep the custom tsushima GRUB theme instead of the generated one
      grub.enable = false;
      # NOTE: stylix (release-26.05) has no sddm target; SDDM login is themed
      # separately in hosts/radon/default.nix.
    };
  };
}
