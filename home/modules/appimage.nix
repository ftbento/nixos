{ config, lib, ... }:
let
  cfg = config.home.appimage;
in {
  options.home.appimage = {
    enable = lib.mkEnableOption "Desktop entries for AppImages found in `directories`";

    directories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "~/Applications"
        "~/Downloads"
        "~/Documents"
      ];
      description = ''
        Directories scanned for `*.AppImage` files. `~/` is expanded at
        activation time. Every AppImage found gets a generated
        `~/.local/share/applications/appimage-*.desktop`, so it shows up in the
        Noctalia launcher (Super+D) without hand-writing entries per app.
      '';
    };

    categories = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "Utility" ];
      description = "Desktop entry Categories (helps the launcher group/sort apps).";
    };
  };

  config = lib.mkIf cfg.enable {
    # AppImages carry no .desktop file, and the Noctalia launcher only indexes
    # desktop entries — so the shell's app list stays empty for them. Exec
    # points straight at the AppImage: the host enables programs.appimage.binfmt
    # (boot.binfmt.registrations), which the kernel applies via
    # systemd-binfmt on every switch, so no `appimage-run` prefix is needed.
    home.activation.appimageLaunchers = lib.hm.dag.entryAfter [ "installPackages" ] ''
      apps_dir="$HOME/.local/share/applications"
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/appimage-launchers"
      manifest="$state_dir/manifest"
      mkdir -p "$apps_dir" "$state_dir"
      new_manifest=$(mktemp)

      for dir in ${lib.escapeShellArgs cfg.directories}; do
        dir="''${dir/#\~/$HOME}"
        [ -d "$dir" ] || continue
        for img in "$dir"/*.AppImage "$dir"/*.appimage; do
          [ -f "$img" ] || continue

          base=$(basename "$img")
          stem="''${base%.AppImage}"
          [ "$stem" = "$base" ] && stem="''${base%.appimage}"

          # HD2Arsenal-0.36.2.AppImage -> "HD2Arsenal" (only strip dotted versions,
          # so names that merely end in a number survive).
          name=$(printf '%s' "$stem" | sed -E 's/[-_.]?[vV]?[0-9]+(\.[0-9]+)+$//')
          id="appimage-$(printf '%s' "$stem" | sed -E 's/[^A-Za-z0-9._-]+/-/g')"
          desktop="$apps_dir/$id.desktop"

          # An icon next to the AppImage wins; otherwise fall back to the generic
          # binary icon instead of leaving the launcher row blank.
          icon="application-x-executable"
          for cand in \
            "$img.png" "$img.svg" \
            "''${img%.*}.png" "''${img%.*}.svg" \
            "$dir/$stem.png" "$dir/$stem.svg" "$dir/.DirIcon"
          do
            if [ -f "$cand" ]; then
              icon="$cand"
              break
            fi
          done

          # Desktop entry Exec quoting: double quotes, with the reserved
          # characters escaped.
          exec_path=$(printf '%s' "$img" | sed -E 's/([\\"$`])/\\\1/g')

          # The kernel only runs it if the bit is set (binfmt still needs +x).
          [ -x "$img" ] || chmod +x "$img" 2>/dev/null || true

          cat > "$desktop.tmp" <<EOF
      [Desktop Entry]
      Type=Application
      Name=$name
      Comment=$name (AppImage)
      Exec=appimage-run "$exec_path" %U
      Icon=$icon
      Terminal=false
      Categories=${lib.concatStringsSep ";" cfg.categories};
      NoDisplay=false
      EOF
          chmod 0644 "$desktop.tmp"
          mv "$desktop.tmp" "$desktop"

          printf '%s\n' "$id.desktop" >> "$new_manifest"
        done
      done

      # Drop entries for AppImages that are gone (renamed/re-downloaded/deleted).
      if [ -f "$manifest" ]; then
        while IFS= read -r old; do
          [ -n "$old" ] || continue
          grep -qxF "$old" "$new_manifest" || rm -f "$apps_dir/$old"
        done < "$manifest"
      fi
      mv "$new_manifest" "$manifest"
      chmod 0644 "$manifest"
    '';
  };
}
