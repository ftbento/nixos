{ config, ... }: {
  # Importing a GPU module pulls in the base graphics stack
  # (OpenGL/Vulkan, 32-bit libs) so it's self-contained.
  imports = [ ../graphics.nix ];

  services.xserver.videoDrivers = [ "nvidia" ];

  boot.initrd.kernelModules = [ "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}