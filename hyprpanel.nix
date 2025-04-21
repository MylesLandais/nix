{
  inputs,
  vars,
  ...
}: {
  imports = [inputs.hyprpanel.homeManagerModules.hyprpanel];
  programs.hyprpanel = {
    enable = true;
    systemd.enable = true;
    overwrite.enable = false;
    settings = {
      layout = {
        "bar.layouts" = {
          "*" = {
            left =
              [
                "dashboard"
                "workspaces"
              ]
              ++ (
                if !vars.isDesktop
                then ["battery"]
                else [""]
              );
            middle = [
              "media"
              "network"
            ];
            right = [
              "volume"
              "bluetooth"
              "systray"
              "clock"
              "notifications"
            ];
          };
        };
      };
      wallpaper.enable = false;
      scalingPriority = "hyprland";
      bar = {
        launcher.autoDetectIcon = true;
        workspaces = {
          show_numbered = true;
          show_icons = false;
        };
        windowtitle = {
          class_name = false;
          custom_title = false;
          truncation_size = 35;
        };
        notifications.show_total = true;
      };
      menus.clock = {
        time = {
          military = true;
          hideSeconds = true;
        };
        weather.unit = "metric";
      };
      menus.dashboard.directories.enabled = false;
      menus.dashboard.stats.enable_gpu = true;
      theme = {
        name = "gruvbox_split";
        bar = {
          transparent = true;
          floating = false;
        };
        font = {
          name = "Hack Nerd Font";
          size = "16px";
        };
      };
    };
  };
}
