{ config, ... }:
{
  home-manager.users.${config.workstation.user}.programs.prismlauncher = {
    enable = true;
  };
}
