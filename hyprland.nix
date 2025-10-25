
{
  pkgs,
  vars,
  config,
  inputs,
  ...
}:
{
  wayland.windowManager.hyprland = {
    enable = true;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
    settings = {
      general = {
        gaps_in = 5;
        gaps_out = 10;
        border_size = 2;
        allow_tearing = true;
        layout = "dwindle";
      };
      decoration = {
        rounding = 10;
        blur = {
          enabled = false;
          size = 7;
          passes = 4;
          new_optimizations = true;
        };
      };
      animations = {
        enabled = true;
        bezier = "myBezier, 0.10, 0.9, 0.1, 1.05";
        animation = [
          "windows, 1, 7, myBezier, slide"
          "windowsOut, 1, 7, myBezier, slide"
          "border, 1, 10, default"
          "borderangle, 1, 8, default"
          "fade, 1, 7, default"
          "workspaces, 1, 6, default"
        ];
      };
      windowrule = [
        "float,title:(Picture-in-Picture)"
        "pin,title:(Picture-in-Picture)"
        "noshadow,title:(Picture-in-Picture)"
        "size 25% 25%,title:(Picture-in-Picture)"
        "move 100%-w-20,title:(Picture-in-Picture)"
        "noinitialfocus,title:(Picture-in-Picture)"
        "float,class:(mpv)"
        "pin,class:(mpv)"
        "noshadow,class:(mpv)"
        "size 50% 50%,class:(mpv)"
        "move 100%-w-20,class:(mpv)"
        "noinitialfocus,class:(mpv)"
        "float, class:(GLava)"
        "size 100% 25%,class:(GLava)"
        "move 100%-w-20,class:(GLava)"
        "noshadow,class:(GLava)"
        "noinitialfocus,title:(GLava)"
      ];
      # Configure your monitors here
      # See https://wiki.hyprland.org/Configuring/Monitors/
      # monitor = <name>,<resolution>,<position>,<scale>
      monitor = [
        "${vars.mainMonitor.name},${toString vars.mainMonitor.width}x${toString vars.mainMonitor.height}@${toString vars.mainMonitor.refresh},0x0,1"
        "${vars.secondaryMonitor.name},${toString vars.secondaryMonitor.width}x${toString vars.secondaryMonitor.height}@${toString vars.secondaryMonitor.refresh},2560x0,1"
      ];
      env = [
        "LIBVA_DRIVER_NAME,nvidia"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "NVD_BACKEND,direct"
        "XDG_SESSION_TYPE,wayland"
        "GBM_BACKEND,nvidia-drm"
        "__GL_GSYNC_ALLOWED,0"
        "__GL_VRR_ALLOWED,0"
        "WLR_NO_HARDWARE_CURSORS,1"
        "NIXOS_OZONE_WL,1"
        "ELECTRON_OZONE_PLATFORM_HINT,auto"
        "XDG_CURRENT_DESKTOP,Hyprland"
        "XDG_SESSION_DESKTOP,Hyprland"
        "XDG_CONFIG_HOME=${config.xdg.configHome}"
        "BROWSER=brave"
        "XCURSOR_SIZE=22"
        "EDITOR=nvim"
        "QT_STYLE_OVERRIDE=''"
      ];
      "$mod" = "SUPER";
      "exec-once" = [
        "hyprpanel &"
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "hyprpaper &"
        "add_record_player"
      ];
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
      bind = [
        "$mod, RETURN, exec,ghostty"
        "$mod, W, exec, brave"
        "$mod, C, exec, Cider"
        "$mod, D, exec,vesktop"
        "$mod, Q, killactive,"
        "$mod, M, exit,"
        "$mod, E, exec, cosmic-files"
        "$mod, B, exec, hyprlock"
        "$mod, N, exec, swaync-client -t -sw"
        "$mod, V, togglefloating,"
        "$mod, R, exec, fuzzel"
        # Hyprshot keybinds
        ", PRINT, exec, hyprshot -m output"  # Full monitor screenshot
        "$mod, S, exec, hyprshot -m region"  # Region selection
        "CTRL, PRINT, exec, hyprshot -m window"  # Active window
        "CTRL SHIFT, PRINT, exec, hyprshot -m region --clipboard-only"  # Region to clipboard only (no save)

        "$mod SHIFT, R, exec, wlogout"
        "$mod, D, exec, vesktop --enable-features=UseOzonePlatform --ozone-platform=wayland --ozone-platform-hint=auto "
        "$mod, H, movefocus, l"
        "$mod, L, movefocus, r"
        "$mod, K, movefocus, u"
        "$mod, J, movefocus, d"
        "$mod, mouse_down, workspace, e+1"
        "$mod, mouse_up, workspace, e-1"
        ", XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ]
      ++ (builtins.concatLists (
        builtins.genList (
          i:
          let
            ws = i + 1;
          in
          [
            "$mod, code:1${toString i},workspace, ${toString ws}"
            "$mod SHIFT, code:1${toString i},movetoworkspace, ${toString ws}"
          ]
        ) 9
      ));
    };
  };
}
