{ pkgs, ... }: {
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
  };

  # Clean PipeWire mixer — switch audio output/input devices and per-app
  # volume. Keybound to SUPER+A in profiles/desktop.nix.
  environment.systemPackages = with pkgs; [
    pwvucontrol
  ];
}