{ config, ... }: {
  services.netbird = {
    # NetBird mesh VPN client daemon + netbird-ui desktop client. Connect once
    # with `netbird up`; setup key auto-login can be added later via
    # services.netbird.clients.default.login.setupKeyFile.
    enable = true;
    ui.enable = true;

    clients.default = {
      # Self-hosted management server (default is api.netbird.io). NetBird
      # persists URLs as JSON objects (net/url has no TextMarshaler), so a
      # plain string here crashes the daemon — keep the object shape.
      config.ManagementURL = {
        Scheme = "https";
        Host = "vpn.hackucf.cloud:443";
      };
    };
  };
}