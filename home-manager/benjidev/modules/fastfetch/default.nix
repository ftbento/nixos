{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        type = "data";
        source = builtins.readFile ./ascii.txt;
        color = {
          "1" = "red";
          "2" = "blue";
        };
        padding = { right = 2; };
      };
      modules = [
        "title"
        "separator"
        "os"
        "host"
        "kernel"
        "uptime"
        "packages"
        "shell"
        "display"
        "de"
        "wm"
        "cpu"
        "gpu"
        "memory"
        "swap"
        "disk"
        "localip"
        "colors"
      ];
    };
  };
}