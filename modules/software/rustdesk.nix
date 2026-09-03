{ pkgs, ... }: {
  environment.systemPackages = [ pkgs.rustdesk-flutter ];

  # XDG portal + gtk backend — required for RustDesk's experimental Wayland
  # screen-sharing (PipeWire capture via the portal).
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };
}
