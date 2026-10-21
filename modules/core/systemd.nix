{
  # stop crashing dm just because of update
  systemd.services.display-manager.restartIfChanged = false;

  services.logind.settings.Login.HandlePowerKey = "suspend";
}