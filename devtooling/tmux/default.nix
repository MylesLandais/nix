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
        tmux-fzf
        continuum
        better-mouse-mode
        harpoon
        dotbar
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
        set -g @plugin 'vaaleyard/tmux-dotbar'
        set -g @tmux-dotbar-bg "#1e1e2e"
        set -g @tmux-dotbar-fg "#585b70"
        set -g @tmux-dotbar-fg-current "#cdd6f4"
        set -g @tmux-dotbar-fg-session "#9399b2"
        set -g @tmux-dotbar-fg-prefix "#cba6f7"
        set -g @tmux-dotbar-justify "absolute-centre"
        set -g @tmux-dotbar-left "true"
        set -g @tmux-dotbar-status-left "#S" # see code
        set -g @tmux-dotbar-right "false"
        set -g @tmux-dotbar-status-right "%H:%M" # see code
        set -g @tmux-dotbar-window-status-format " #W "
        set -g @tmux-dotbar-window-status-separator " • "
        set -g @tmux-dotbar-maximized-icon "󰊓"
        set -g @tmux-dotbar-show-maximized-icon-for-all-tabs false
        set -g @plugin sainnhe/tmux-fzf
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
