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
        resurrect
        continuum
        better-mouse-mode
        {
          plugin = kanagawa;
          extraConfig = ''
            set -g @kanagawa-theme 'dragon'
            set -g @kanagawa-plugins "git weather playerctl kubernetes-context"
            set -g @kanagawa-show-powerline true
            set -g @kanagawa-refresh-rate 5
            set -g @kanagawa-git-show-current-symbol ✓
            set -g @kanagawa-git-show-diff-symbol !
            set -g @kanagawa-git-show-remote-status true
            set -g @kanagawa-show-location false
            set -g @kanagawa-fixed-location "Madrid"
            set -g @kanagawa-show-empty-plugins false
            set -g @kanagawa-kubernetes-hide-user true
            set -g @kanagawa-playerctl-format "►  {{ artist }} - {{ title }}"
          '';
        }
      ];
      extraConfig = ''
        bind-key h select-pane -L
        bind-key j select-pane -D
        bind-key k select-pane -U
        bind-key l select-pane -R
        set -g status "on"
        set -g mouse "on"
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
