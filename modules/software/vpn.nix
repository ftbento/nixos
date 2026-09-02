{ config, lib, pkgs, ... }: let
  cfg = config.workstation.vpn;
in {
  options.workstation.vpn = {
    enable = lib.mkEnableOption "VPN support (openconnect/AnyConnect for UCF via NetworkManager)";
  };

  config = lib.mkIf cfg.enable {
    networking.networkmanager.plugins = with pkgs; [
      networkmanager-openconnect
    ];

    environment.systemPackages = with pkgs; [
      openconnect
      networkmanagerapplet
    ];

    # Declarative UCF AnyConnect connection (SAML/SSO — no stored credentials)
    environment.etc."NetworkManager/system-connections/ucf-anyconnect.nmconnection" = {
      mode = "0600";
      text = ''
        [connection]
        id=UCF AnyConnect
        uuid=4b3f0a3e-1c2d-4e8a-9f6d-3a2b5c7d8e9f
        type=vpn
        autoconnect=false
        permissions=

        [vpn]
        service-type=org.freedesktop.NetworkManager.openconnect
        gateway=secure.vpn.ucf.edu
        protocol=anyconnect
        useragent=AnyConnect

        [ipv4]
        method=auto

        [ipv6]
        method=auto

        [vpn-secrets]
      '';
    };
  };
}
