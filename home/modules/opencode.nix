{ config, lib, ... }: {
  options.home.opencode.enable = lib.mkEnableOption "declarative opencode global config";

  config = lib.mkIf config.home.opencode.enable {
    home.file.".config/opencode/opencode.jsonc".text = ''
      {
        "$schema": "https://opencode.ai/config.json",
        "permission": {
          "external_directory": {
            "/tmp/**": "allow"
          }
        }
      }
    '';
  };
}