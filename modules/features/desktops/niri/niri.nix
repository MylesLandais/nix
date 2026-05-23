{
  lib,
  config,
  osConfig,
  pkgs,
  ...
}:
{
  config = {
    bars = {
      noctalia.enable = lib.mkIf (osConfig.host.bar == "noctalia") true;
    };

    programs.niri = {
      settings = {
        outputs =
          let
            mkOutput = m: {
              mode = {
                width = lib.toInt m.width;
                height = lib.toInt m.height;
                refresh = lib.toFloat m.refresh;
              };
            };
          in
          {
            "${osConfig.host.mainMonitor.name}" = mkOutput osConfig.host.mainMonitor;
          }
          // lib.optionalAttrs (osConfig.host ? secondaryMonitor) {
            "${osConfig.host.secondaryMonitor.name}" = mkOutput osConfig.host.secondaryMonitor;
          };

        input = {
          keyboard.xkb.layout = "us";
          touchpad = {
            tap = true;
            natural-scroll = true;
          };
          focus-follows-mouse.enable = true;
        };

        layout = {
          gaps = 8;
          border = {
            enable = true;
            width = 2;
          };
          preset-column-widths = [
            { proportion = 1.0 / 3.0; }
            { proportion = 1.0 / 2.0; }
            { proportion = 2.0 / 3.0; }
          ];
          default-column-width.proportion = 1.0 / 2.0;
        };

        binds =
          with config.lib.niri.actions;
          let
            sh = spawn "sh" "-c";
          in
          {
            "Mod+Return".action = spawn "ghostty";
            "Mod+Q".action = close-window;
            "Mod+D".action = spawn "fuzzel";
            "Mod+Shift+Escape".action = spawn "swaylock";

            "Mod+H".action = focus-column-left;
            "Mod+L".action = focus-column-right;
            "Mod+J".action = focus-window-down;
            "Mod+K".action = focus-window-up;

            "Mod+Shift+H".action = move-column-left;
            "Mod+Shift+L".action = move-column-right;

            "Mod+1".action = focus-workspace 1;
            "Mod+2".action = focus-workspace 2;
            "Mod+3".action = focus-workspace 3;
            "Mod+4".action = focus-workspace 4;
            "Mod+5".action = focus-workspace 5;
            "Mod+6".action = focus-workspace 6;
            "Mod+7".action = focus-workspace 7;
            "Mod+8".action = focus-workspace 8;
            "Mod+9".action = focus-workspace 9;

            "Mod+Shift+1".action = move-column-to-workspace 1;
            "Mod+Shift+2".action = move-column-to-workspace 2;
            "Mod+Shift+3".action = move-column-to-workspace 3;
            "Mod+Shift+4".action = move-column-to-workspace 4;
            "Mod+Shift+5".action = move-column-to-workspace 5;
            "Mod+Shift+6".action = move-column-to-workspace 6;
            "Mod+Shift+7".action = move-column-to-workspace 7;
            "Mod+Shift+8".action = move-column-to-workspace 8;
            "Mod+Shift+9".action = move-column-to-workspace 9;

            "Mod+R".action = switch-preset-column-width;
            "Mod+F".action = maximize-column;
            "Mod+Shift+F".action = fullscreen-window;
            "Mod+Space".action = toggle-window-floating;

            "Mod+Shift+S".action = sh "grim -g \"$(slurp)\" - | wl-copy";

            "XF86AudioRaiseVolume".action = sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
            "XF86AudioLowerVolume".action = sh "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
            "XF86AudioMute".action = sh "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
            "XF86MonBrightnessUp".action = sh "brightnessctl set 5%+";
            "XF86MonBrightnessDown".action = sh "brightnessctl set 5%-";
          };

        spawn-at-startup = [
          { command = [ "swaybg" "-i" (toString osConfig.host.wallpaper) "-m" "fill" ]; }
        ];
      };
    };
  };
}
