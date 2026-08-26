{ config, lib, pkgs, ... }: {
  boot.kernelModules = [ "amdgpu" ];

  services.xserver.videoDrivers = [ "amdgpu" ];

  # RADV (Mesa's Vulkan driver for AMD) is enabled by default via hardware.graphics;
  # this enables full OpenGL + Vulkan for both 64-bit and 32-bit (for games).
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  environment.systemPackages = with pkgs; [
    vulkan-tools
  ];
}