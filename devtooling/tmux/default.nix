
{pkgs,lib,config, ...}:
{
  options = {
    tmux.enable = lib.mkEnableOption "Enable tmux module";
  };
  config = lib.mkIf config.tmux.enable {
    programs.tmux = {
      enable = true;
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
        set-option -g status-position top
        '';

    };
  };

}
