{ config, lib, pkgs, inputs, ... }: let
  system = pkgs.stdenv.hostPlatform.system;
  pkgs-unstable = inputs.nixpkgs-unstable.legacyPackages.${system};

  # yazi's built-in video previewer shells out to `ffmpeg -hwaccel auto`. On this
  # AMD-only box that probes CUDA/NVDEC (prints "Could not dynamically load CUDA"
  # noise) and can pick a flaky Vulkan decode path that makes the preview fail.
  # Strip `-hwaccel` so frame extraction always uses software decode: no probe
  # noise, no failure surface, still a working thumbnail.
  ffmpeg-software = pkgs.writeShellScriptBin "ffmpeg" ''
    args=()
    skip=0
    for a in "$@"; do
      if [ "$skip" -eq 1 ]; then skip=0; continue; fi
      if [ "$a" = "-hwaccel" ]; then skip=1; continue; fi
      args+=("$a")
    done
    exec ${pkgs.ffmpeg}/bin/ffmpeg "''${args[@]}"
  '';

  # yazi ships ffmpeg-headless (built with cuvid/nvenc/nvdec/cuda-llvm) as an
  # optional dep — exactly the binary whose `-hwaccel auto` probes CUDA and
  # fails. Replace it in its own runtimePaths slot with our strip-`-hwaccel`
  # shim (earlier entries take PATH precedence over `extras`), and keep a real
  # ffmpeg right behind it so `ffprobe`/`ffplay` stay available.
  yazi = pkgs-unstable.yazi.override {
    optionalDeps = [
      pkgs-unstable.jq
      pkgs-unstable.poppler-utils
      pkgs-unstable._7zz
      ffmpeg-software # replaces ffmpeg-headless
      pkgs.ffmpeg
      pkgs-unstable.fd
      pkgs-unstable.ripgrep
      pkgs-unstable.fzf
      pkgs-unstable.zoxide
      pkgs-unstable.imagemagick
      pkgs-unstable.chafa
      pkgs-unstable.resvg
    ];
  };
in {
  options.home.yazi.enable = lib.mkEnableOption "Yazi file manager";

  config = lib.mkIf config.home.yazi.enable {
    # mpv is installed by programs.mpv below (it pulls in the uosc-enabled
    # wrapper); keeping the plain `mpv` here too would duplicate bin/mpv in
    # buildEnv and break activation. Its mpv.desktop is thereby exposed to xdg
    # for the mimeApps defaults below.

    programs.mpv = {
      enable = true;
      scripts = [ pkgs.mpvScripts.uosc ];
      scriptOpts = {
        uosc = {
          title = "yes";
          time_total_fontsize = 11;
          time_current_fontsize = 12;
        };
      };
      config = {
        hwdec = "vaapi";
        keep-open = "yes";
      };
    };

    programs.yazi = {
      enable = true;
      # 26.9 embeds the built-in `video` previewer/preloader; 26.5.6 from
      # the stable channel doesn't. We also swap out its bundled
      # ffmpeg-headless for a no-`-hwaccel` wrapper (see `yazi` above).
      package = yazi;

      settings = {
        yazi = {
          ratio = [ 1 4 3 ];
          sort_by = "natural";
          sort_sensitive = true;
          sort_reverse = false;
          sort_dir_first = true;
          linemode = "none";
          show_hidden = true;
          show_symlink = true;
        };

        # Replace the default `xdg-open` "play" opener so Enter on a video
        # launches mpv directly (the default `{audio,video}/* -> play` open rule
        # still applies).
        opener = {
          play = [
            {
              run = "mpv --force-window=immediate %s";
              desc = "Play with mpv";
              orphan = true;
              for = "linux";
            }
          ];
        };
      };
    };

    # Let xdg-open (e.g. the default `open` opener, file managers, browsers with
    # `xdg-open`) open video with mpv too.
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "video/mp4" = "mpv.desktop";
        "video/x-matroska" = "mpv.desktop"; # .mkv
        "video/webm" = "mpv.desktop";
        "video/quicktime" = "mpv.desktop"; # .mov
        "video/x-msvideo" = "mpv.desktop"; # .avi
        "video/mp2t" = "mpv.desktop"; # .ts / .mts
        "video/3gpp" = "mpv.desktop";
      };
    };
  };
}