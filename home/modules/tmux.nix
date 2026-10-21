{ config, lib, pkgs, ... }:
{
  options.home.tmux.enable = lib.mkEnableOption "tmux terminal multiplexer";

  config = lib.mkIf config.home.tmux.enable {
    programs.tmux = {
      enable = true;

      # The user's shell is fish (programs.fish); make new panes/windows open it
      # too instead of falling back to bash.
      shell = "${pkgs.fish}/bin/fish";
      terminal = "tmux-256color";

      # Ctrl+a is easier to reach than the default Ctrl+b and mirrors screen.
      prefix = "C-a";

      # Treat `|` and `-` as vertical/horizontal splits, plus intuitive nav.
      keyMode = "vi";
      # Vim-style pane navigation and resizing.
      extraConfig = ''
        # Splits on the keys you'd expect (current path preserved).
        bind | split-window -h -c "#{pane_current_path}"
        bind - split-window -v -c "#{pane_current_path}"
        unbind '"'
        unbind %

        # vim-tmux-navigator style pane movement (works with hyprland's vim keys).
        bind h select-pane -L
        bind j select-pane -D
        bind k select-pane -U
        bind l select-pane -R

        # Reload config with prefix + r.
        bind r source-file ~/.config/tmux/tmux.conf \; display "Reloaded!"

        # Start window/pane numbering at 1 to match the keyboard.
        set -g base-index 1
        setw -g pane-base-index 1
        set -g renumber-windows on

        # Ctrl+a a sends a literal Ctrl+a to the running program.
        set -g prefix2 C-a

        set -g escape-time 0
        set -g history-limit 10000
        set -g focus-events on
      '';

      # Mouse support (click panes, resize, scroll).
      mouse = true;

      # Status bar is themed via Stylix (stylix.targets.tmux). The default
      # green/black bar is disabled so the theme's colours show.
      plugins = with pkgs.tmuxPlugins; [
        sensible
      ];
    };
  };
}
