{
  # stop crashing dm just because of update
  systemd.services.display-manager.restartIfChanged = false;
}