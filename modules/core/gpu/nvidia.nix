{config, ...}: {
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = false; # Set to true if you prefer the open-source kernel modules
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}