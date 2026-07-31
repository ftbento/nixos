{ config, pkgs, inputs, ... }: {
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
    # Back up existing config files instead of failing when HM wants to take
    # them over (e.g. Stylix-generated gtk.css, fuzzel.ini, btop.conf, ...).
    backupFileExtension = "hm-backup";
  };
}
