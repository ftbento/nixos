{ ... }: {
  # LocalSend — cross-platform AirDrop alternative (LAN file sharing).
  # openFirewall defaults to true: opens TCP/UDP 53317 for receiving.
  programs.localsend = {
    enable = true;
    openFirewall = true;
  };
}
