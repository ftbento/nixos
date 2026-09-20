{ config, pkgs, ... }: {
  # Importing a GPU module pulls in the base graphics stack
  # (OpenGL/Vulkan, 32-bit libs) so it's self-contained.
  imports = [ ../graphics.nix ];

  boot.kernelModules = [ "amdgpu" ];

  services.xserver.videoDrivers = [ "amdgpu" ];

  environment.systemPackages = with pkgs; [
    vulkan-tools
  ];
}