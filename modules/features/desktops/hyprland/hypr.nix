{
  lib,
  pkgs,
  osConfig,
  config,
  inputs,
  ...
}:
let
  c = osConfig.host.themeData.base16Scheme;
  rgb = color: "rgb(${color})";
  rgba = color: alpha: "rgba(${color}${alpha})";

  mod = "SUPER";

  add_record_player = pkgs.writeShellApplication {
    name = "add_record_player";
    text = ''
      # Wait a moment for audio services to fully start
      sleep 2
      pactl set-source-volume alsa_input.usb-BurrBrown_from_Texas_Instruments_USB_AUDIO_CODEC-00.pro-input-0 65536
      pactl set-source-mute alsa_input.usb-BurrBrown_from_Texas_Instruments_USB_AUDIO_CODEC-00.pro-input-0 false
      pactl set-sink-volume alsa_output.usb-Focusrite_Scarlett_Solo_USB_Y7RBNDQ2A68E32-00.pro-output-0 65536
      pactl set-sink-mute alsa_output.usb-Focusrite_Scarlett_Solo_USB_Y7RBNDQ2A68E32-00.pro-output-0 false
      pactl load-module module-loopback source=alsa_input.usb-BurrBrown_from_Texas_Instruments_USB_AUDIO_CODEC-00.pro-input-0 sink=alsa_output.usb-Focusrite_Scarlett_Solo_USB_Y7RBNDQ2A68E32-00.pro-output-0
      echo "PCM2900C to Scarlett Solo loopback configured successfully"
    '';
  };

  execOnce =
    [
      "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
      "add_record_player"
      "wl-paste --watch cliphist store &"
    ]
    ++ lib.optionals (osConfig.host.bar == "noctalia") [ "noctalia-shell" ];
in
{
  options = {
    hypr.enable = lib.mkEnableOption "Enable hypr module";
  };
  config = lib.mkIf config.hypr.enable {
    home.packages = [
      add_record_player
    ];
    dbus.packages = [
      pkgs.pass-secret-service
      pkgs.gcr
      pkgs.gnome-settings-daemon
      pkgs.libsecret
    ];

    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";
      portalPackage = pkgs.xdg-desktop-portal-hyprland;

      extraConfig = ''
        -- == Config ==
        hl.config({
          general = {
            gaps_in = 5,
            gaps_out = 10,
            border_size = 2,
            allow_tearing = true,
            layout = "dwindle",
            ["col.active_border"] = "${rgb c.base0D}",
            ["col.inactive_border"] = "${rgb c.base03}",
          },
          decoration = {
            rounding = 10,
            blur = {
              enabled = true,
              size = 7,
              passes = 3,
              new_optimizations = true,
              noise = 0.08,
              contrast = 1.5,
              xray = false,
              ignore_opacity = true,
            },
            shadow = {
              color = "${rgba c.base00 "99"}",
            },
          },
          input = {
            kb_layout = "us",
            kb_variant = "altgr-intl",
            touchpad = {
              clickfinger_behavior = true,
              natural_scroll = true,
            },
          },
          misc = {
            background_color = "${rgb c.base00}",
          },
          group = {
            ["col.border_active"] = "${rgb c.base0D}",
            ["col.border_inactive"] = "${rgb c.base03}",
            ["col.border_locked_active"] = "${rgb c.base0C}",
            groupbar = {
              ["col.active"] = "${rgb c.base0D}",
              ["col.inactive"] = "${rgb c.base03}",
              text_color = "${rgb c.base05}",
            },
          },
          animations = {
            enabled = true,
          },
        })

        -- == Curves ==
        hl.curve("myBezier", { points = {{0.10, 0.9}, {0.1, 1.05}}, type = "bezier" })
        hl.curve("wind",     { points = {{0.05, 0.9}, {0.1, 1.05}}, type = "bezier" })
        hl.curve("windIn",   { points = {{0.1,  1.1}, {0.1, 1.1}},  type = "bezier" })
        hl.curve("windOut",  { points = {{0.3,  -0.3}, {0,   1}},  type = "bezier" })
        hl.curve("liner",    { points = {{1,    1},   {1,   1}},  type = "bezier" })

        -- == Animations ==
        hl.animation({ bezier = "wind",    enabled = true, leaf = "windows",     speed = 6,  style = "slide" })
        hl.animation({ bezier = "windIn",  enabled = true, leaf = "windowsIn",   speed = 6,  style = "slide" })
        hl.animation({ bezier = "windOut", enabled = true, leaf = "windowsOut",  speed = 5,  style = "slide" })
        hl.animation({ bezier = "wind",    enabled = true, leaf = "windowsMove", speed = 5,  style = "slide" })
        hl.animation({ bezier = "liner",   enabled = true, leaf = "border",      speed = 1 })
        hl.animation({ bezier = "liner",   enabled = true, leaf = "borderangle", speed = 30, style = "loop" })
        hl.animation({ bezier = "wind",    enabled = true, leaf = "workspaces",  speed = 10 })

        -- == Gestures ==
        hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
        hl.gesture({ fingers = 3, direction = "down",       action = "close" })
        hl.gesture({ fingers = 3, direction = "up",         action = (function() hl.exec_cmd("noctalia-shell ipc call launcher toggle") end) })

        -- == Window Rules ==
        hl.window_rule({ float = true, pin = true, no_shadow = true, size = "(monitor_w*0.25) (monitor_h*0.25)", move = "(monitor_w - window_w - 20) 20", no_initial_focus = true, match = { title = "Picture-in-Picture" } })
        hl.window_rule({ float = true, match = { class = "^(pavucontrol)$" } })
        hl.window_rule({ float = true, match = { title = "^(Volume Control)$" } })
        hl.window_rule({ float = true, pin = true, no_shadow = true, size = "(monitor_w*0.5) (monitor_h*0.5)", move = "(monitor_w - window_w - 20) 20", no_initial_focus = true, match = { class = "mpv" } })
        hl.window_rule({ opacity = 0.90, match = { class = "^(vesktop)$" } })
        hl.window_rule({ opacity = 1.0, no_blur = true, match = { class = "^(zen-beta)$" } })

        -- == Binds ==
        ${import ./config/bindings.nix { inherit lib mod; bar = osConfig.host.bar; }}

        -- == Base env ==
        hl.env("XCURSOR_SIZE", "22")
        hl.env("EDITOR", "nvim")
        hl.env("QT_STYLE_OVERRIDE", "")

        -- == Exec-once ==
        hl.on("hyprland.start", function()
        ${lib.concatMapStrings (cmd: "  hl.exec_cmd(\"${cmd}\")\n") execOnce}end)
      '';
    };
  };
}
