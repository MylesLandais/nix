{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    tmux.enable = lib.mkEnableOption "Enable tmux module";
  };
  config = lib.mkIf config.tmux.enable {
    programs.tmux = {
      enable = true;
      keyMode = "vi";
      shortcut = "a";
      plugins = with pkgs.tmuxPlugins; [
        tokyo-night-tmux
        resurrect
        continuum
        better-mouse-mode
      ];
      extraConfig = ''
        bind-key h select-pane -L
        bind-key j select-pane -D
        bind-key k select-pane -U
        bind-key l select-pane -R
        set -g status "on"
        set -g allow-passthrough on
        set-option -g status-position top
        set -g @resurrect-strategy-vim "session"
        set -g @resurrect-strategy-nvim "session"
        set -g @resurrect-capture-pane-contents "on"
        set -g @continuum-restore "on"
        set -g @continuum-boot "on"
        set -g @continuum-save-interval "10"
      '';
    };
  };
}
