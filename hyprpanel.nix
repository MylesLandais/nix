{
  inputs,
  vars,
  ...
}:
{
  imports = [ inputs.hyprpanel.homeManagerModules.hyprpanel ];
  programs.hyprpanel = {
    enable = true;
    overwrite.enable = false;
    settings = {
      layout = {
        "bar.layouts" = {
          "*" = {
            left = [
              "dashboard"
              "workspaces"
            ] ++ (if !vars.isDesktop then [ "battery" ] else [ "" ]);
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
        osd.radius = "0.7em";
        bar = {
          transparent = true;
          border_radius = "1.5em";
          floating = false;
          buttons = {
            radius = "1em";
            workspaces.pill.radius = "2.5rem * 0.7";
          };
          menus = {
            border.radius = "1em";
            card_radius = "1em";
            popover.radius = "1em";
            progressbar.radius = "1em";
          };
        };
        font = {
          name = "Hack Nerd Font";
          size = "16px";
        };
      };
    };
  };
}
