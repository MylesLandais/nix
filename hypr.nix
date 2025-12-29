{
  pkgs,
  vars,
  config,
  inputs,
  ...
}:
let
  add_record_player = pkgs.writeShellApplication {
    name = "add_record_player";
    text = ''
      # Wait a moment for audio services to fully start
      sleep 2
      # Set PCM2900C input volume to 100%
      pactl set-source-volume alsa_input.usb-BurrBrown_from_Texas_Instruments_USB_AUDIO_CODEC-00.pro-input-0 65536
      # Unmute PCM2900C input
      pactl set-source-mute alsa_input.usb-BurrBrown_from_Texas_Instruments_USB_AUDIO_CODEC-00.pro-input-0 false
      # Set Scarlett Solo output volume to 100%
      pactl set-sink-volume alsa_output.usb-Focusrite_Scarlett_Solo_USB_Y7RBNDQ2A68E32-00.pro-output-0 65536
      # Unmute Scarlett Solo output
      pactl set-sink-mute alsa_output.usb-Focusrite_Scarlett_Solo_USB_Y7RBNDQ2A68E32-00.pro-output-0 false
      # Create loopback from PCM2900C input to Scarlett Solo output
      pactl load-module module-loopback source=alsa_input.usb-BurrBrown_from_Texas_Instruments_USB_AUDIO_CODEC-00.pro-input-0 sink=alsa_output.usb-Focusrite_Scarlett_Solo_USB_Y7RBNDQ2A68E32-00.pro-output-0
      echo "PCM2900C to Scarlett Solo loopback configured successfully"
    '';
  };
in
{
  # Home packages
  home.packages = [
    add_record_player
    # Thumbnail backend packages for tumbler
    pkgs.ffmpegthumbnailer  # video thumbnails
    pkgs.poppler            # PDF thumbnails
  ];

  # ---------------------------------------------------------
  # XDG portal configuration - ensure a file picker backend is available
  # and prefer the GTK portal for file chooser requests (used by Electron/GTK apps)
  # ---------------------------------------------------------
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      common = {
        default = [ "gtk" ];
      };
      hyprland = {
        default = [ "gtk" "hyprland" ];
      };
    };
  };

  # Hyprland Window Manager Configuration
  wayland.windowManager.hyprland = {
    enable = true;
    # portalPackage is managed via `xdg.portal` above so we don't set it here
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
      windowrulev2 = [
        "opacity 1.0 override 1.0 override,class:^(chromium|Chromium|vivaldi|Vivaldi)$"
        "noblur,class:^(chromium|Chromium|vivaldi|Vivaldi)$"
      ];
      monitor = [
        # Bottom row - Three Dell monitors at y=2160
        "${vars.tertiaryMonitor.name},${toString vars.tertiaryMonitor.width}x${toString vars.tertiaryMonitor.height}@${toString vars.tertiaryMonitor.refresh},5900x2160,1"  # Left Dell
        "${vars.mainMonitor.name},${toString vars.mainMonitor.width}x${toString vars.mainMonitor.height}@${toString vars.mainMonitor.refresh},7820x2160,1"      # Middle Dell (Main)
        "${vars.secondaryMonitor.name},${toString vars.secondaryMonitor.width}x${toString vars.secondaryMonitor.height}@${toString vars.secondaryMonitor.refresh},10380x2160,1"  # Right Dell
        # Top row - Samsung monitor centered above middle
        "${vars.fourthMonitor.name},${toString vars.fourthMonitor.width}x${toString vars.fourthMonitor.height}@${toString vars.fourthMonitor.refresh},8140x1080,1"  # Samsung (Top)
      ];
      workspace = [
        "1,monitor:${vars.tertiaryMonitor.name},default:true"
        "2,monitor:${vars.mainMonitor.name},default:true"
        "3,monitor:${vars.secondaryMonitor.name},default:true"
        "4,monitor:${vars.tertiaryMonitor.name}"
        "5,monitor:${vars.mainMonitor.name}"
        "6,monitor:${vars.secondaryMonitor.name}"
        "7,monitor:${vars.tertiaryMonitor.name}"
        "8,monitor:${vars.mainMonitor.name}"
        "9,monitor:${vars.secondaryMonitor.name}"
        "10,monitor:${vars.fourthMonitor.name},default:true"
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
  "BROWSER=Firefox"
  # Force GTK apps to use the xdg portal for file choosers
  "GTK_USE_PORTAL,1"
        "XCURSOR_SIZE=22"
        "EDITOR=nvim"
        "QT_STYLE_OVERRIDE=''"
      ];
      "$mod" = "SUPER";
      "exec-once" = [
        "dbus-update-activation-environment --systemd DISPLAY HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP && systemctl --user stop hyprland-session.target && systemctl --user start hyprland-session.target"
        "hyprpanel &"
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
        "hyprpaper &"
        "add_record_player"
      ];
      bindm = [
        "$mod, mouse:272, movewindow"
        "$mod, mouse:273, resizewindow"
      ];
      bind = [
        "$mod, RETURN, exec,ghostty"
        "$mod, W, exec, chromium"
        "$mod, C, exec, Cider"
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
        "$mod, D, exec, vesktop --enable-features=UseOzonePlatform --ozone-platform=wayland --ozone-platform-hint=auto"
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
        ) 10  # Extended from 9 to 10 workspaces
      ));
    };
  };

  # Hyprpaper Service
  services.hyprpaper = {
    enable = true;
    package = pkgs.hyprpaper;
    settings = {
      ipc = "on";
      splash = false;
      preload = [ vars.wallpaper ];
      wallpaper = [
        "${vars.mainMonitor.name},${vars.wallpaper}"
        "${vars.secondaryMonitor.name},${vars.wallpaper}"
        "${vars.tertiaryMonitor.name},${vars.wallpaper}"
        "${vars.fourthMonitor.name},${vars.wallpaper}"
      ];
    };
  };

  # DBus Packages
  dbus.packages = [
    pkgs.pass-secret-service
    pkgs.gcr
    pkgs.gnome-settings-daemon
    pkgs.libsecret
  ];

  # Declarative symlink for Ristretto local path access
  home.file."Hydra".source = config.lib.file.mkOutOfStoreSymlink 
    "/run/user/1000/gvfs/smb-share:server=hydra,share=data";

  # Systemd service to auto-mount SMB share
  systemd.user.services.mount-hydra = {
    Unit = {
      Description = "Mount Hydra SMB Share";
      After = [ "graphical-session.target" "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${pkgs.glib}/bin/gio mount smb://hydra/data";
      Restart = "on-failure";
      RestartSec = "30s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
