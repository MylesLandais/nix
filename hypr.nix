{
  pkgs,
  lib,
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

  hyprland_workspace_recovery = pkgs.writeShellApplication {
    name = "hyprland-workspace-recovery";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      gnugrep
      jq
      socat
      util-linux
    ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      readonly CACHE_DIR="''${XDG_CACHE_HOME:-$HOME/.cache}/hyprland-workspace-recovery"
      readonly RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/tmp}/hyprland-workspace-recovery"
      readonly STATE_FILE="$CACHE_DIR/state.json"
      readonly LOCK_FILE="$RUNTIME_DIR/recover.lock"
      readonly LAST_EVENT_FILE="$RUNTIME_DIR/last-event"
      readonly LOG_TAG="hyprland-workspace-recovery"
      readonly DEBOUNCE_SECONDS="''${DEBOUNCE_SECONDS:-2}"
      readonly STABLE_POLLS="''${STABLE_POLLS:-3}"
      readonly STABILIZE_INTERVAL="''${STABILIZE_INTERVAL:-1}"
      readonly STABILIZE_TIMEOUT="''${STABILIZE_TIMEOUT:-20}"
      readonly SOCKET_PATH="''${XDG_RUNTIME_DIR:-/tmp}/hypr/''${HYPRLAND_INSTANCE_SIGNATURE:-}/.socket2.sock"

      readonly -a MANAGED_WORKSPACES=(1 2 3 4 5 6 7 8 9 10)
      readonly HEADLESS_WORKSPACE="99"

      declare -Ar DEFAULT_TARGETS=(
        ["1"]=${lib.escapeShellArg vars.tertiaryMonitor.name}
        ["2"]=${lib.escapeShellArg vars.mainMonitor.name}
        ["3"]=${lib.escapeShellArg vars.secondaryMonitor.name}
        ["4"]=${lib.escapeShellArg vars.tertiaryMonitor.name}
        ["5"]=${lib.escapeShellArg vars.mainMonitor.name}
        ["6"]=${lib.escapeShellArg vars.secondaryMonitor.name}
        ["7"]=${lib.escapeShellArg vars.tertiaryMonitor.name}
        ["8"]=${lib.escapeShellArg vars.mainMonitor.name}
        ["9"]=${lib.escapeShellArg vars.secondaryMonitor.name}
        ["10"]=${lib.escapeShellArg vars.fourthMonitor.name}
        ["99"]="HEADLESS-1"
      )

      mkdir -p "$CACHE_DIR" "$RUNTIME_DIR"

      log() {
        printf '%s [%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$LOG_TAG" "$*"
      }

      have_hyprland_env() {
        [[ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]
      }

      hypr_monitors_json() {
        hyprctl monitors -j
      }

      hypr_workspaces_json() {
        hyprctl workspaces -j
      }

      current_topology_key() {
        hypr_monitors_json | jq -rc '
          map(
            if (.description // "") != ""
            then "desc:" + .description
            else .name
            end
          )
          | sort
          | join("|")
        '
      }

      wait_for_stable_topology() {
        local deadline key last_key=""
        local stable_count=0
        deadline=$((SECONDS + STABILIZE_TIMEOUT))

        while (( SECONDS < deadline )); do
          if ! key="$(current_topology_key 2>/dev/null)"; then
            sleep "$STABILIZE_INTERVAL"
            continue
          fi

          if [[ -n "$key" && "$key" == "$last_key" ]]; then
            stable_count=$((stable_count + 1))
          else
            stable_count=1
            last_key="$key"
          fi

          if (( stable_count >= STABLE_POLLS )); then
            printf '%s\n' "$key"
            return 0
          fi

          sleep "$STABILIZE_INTERVAL"
        done

        if [[ -n "$last_key" ]]; then
          printf '%s\n' "$last_key"
          return 0
        fi

        return 1
      }

      snapshot_state() {
        local topology now tmp
        topology="$(wait_for_stable_topology)" || {
          log "Snapshot skipped: topology never stabilized"
          return 1
        }

        now="$(date --iso-8601=seconds)"
        tmp="$(mktemp "$CACHE_DIR/state.XXXXXX.json")"

        jq -n \
          --arg created_at "$now" \
          --arg topology "$topology" \
          --argjson monitors "$(hypr_monitors_json)" \
          --argjson workspaces "$(hypr_workspaces_json)" \
          --arg default_1 "${vars.tertiaryMonitor.name}" \
          --arg default_2 "${vars.mainMonitor.name}" \
          --arg default_3 "${vars.secondaryMonitor.name}" \
          --arg default_4 "${vars.tertiaryMonitor.name}" \
          --arg default_5 "${vars.mainMonitor.name}" \
          --arg default_6 "${vars.secondaryMonitor.name}" \
          --arg default_7 "${vars.tertiaryMonitor.name}" \
          --arg default_8 "${vars.mainMonitor.name}" \
          --arg default_9 "${vars.secondaryMonitor.name}" \
          --arg default_10 "${vars.fourthMonitor.name}" \
          '
          def stable_id_for_monitor($monitors; $name):
            ($monitors[] | select(.name == $name) |
              (if (.description // "") != "" then "desc:" + .description else .name end)
            );

          {
            created_at: $created_at,
            topology: $topology,
            mappings:
              reduce [1,2,3,4,5,6,7,8,9,10][] as $ws (
                {
                  "1": $default_1,
                  "2": $default_2,
                  "3": $default_3,
                  "4": $default_4,
                  "5": $default_5,
                  "6": $default_6,
                  "7": $default_7,
                  "8": $default_8,
                  "9": $default_9,
                  "10": $default_10,
                  "99": "HEADLESS-1"
                };
                .[(($ws|tostring))] =
                  (
                    ($workspaces[] | select((.id|tostring) == ($ws|tostring)) | .monitor) as $monitor_name
                    | if $monitor_name == null
                      then .[(($ws|tostring))]
                      else stable_id_for_monitor($monitors; $monitor_name) // .[(($ws|tostring))]
                      end
                  )
              )
          }
          ' > "$tmp"

        mv "$tmp" "$STATE_FILE"
        log "Captured workspace snapshot at $STATE_FILE"
      }

      target_for_workspace() {
        local workspace="$1"
        if [[ -f "$STATE_FILE" ]]; then
          jq -r --arg ws "$workspace" '.mappings[$ws] // empty' "$STATE_FILE"
        else
          printf '%s\n' "''${DEFAULT_TARGETS[$workspace]:-}"
        fi
      }

      resolve_monitor_name() {
        local target="$1"
        hypr_monitors_json | jq -r --arg target "$target" '
          map({
            stable: (if (.description // "") != "" then "desc:" + .description else .name end),
            name
          })
          | map(select(.stable == $target or .name == $target))
          | .[0].name // empty
        '
      }

      apply_mapping() {
        local workspace="$1"
        local target="$2"
        local resolved_name=""

        [[ -n "$target" ]] || return 0
        resolved_name="$(resolve_monitor_name "$target")"

        if [[ -z "$resolved_name" ]]; then
          log "Skipping workspace $workspace: target monitor $target is unavailable"
          return 0
        fi

        log "Moving workspace $workspace to $resolved_name ($target)"
        hyprctl dispatch moveworkspacetomonitor "$workspace" "$resolved_name" >/dev/null
      }

      refresh_panel() {
        if systemctl --user --quiet is-active hyprpanel.service 2>/dev/null; then
          systemctl --user restart hyprpanel.service >/dev/null 2>&1 || true
          log "Restarted hyprpanel.service"
          return 0
        fi

        if command -v hyprpanel >/dev/null 2>&1; then
          hyprpanel restart >/dev/null 2>&1 || true
          log "Ran hyprpanel restart"
        fi
      }

      recover() {
        local reason="manual"
        if [[ "''${1:-}" == "--reason" ]]; then
          reason="''${2:-manual}"
        fi

        have_hyprland_env || {
          log "Recovery skipped: HYPRLAND_INSTANCE_SIGNATURE is not available"
          return 1
        }

        exec 9>"$LOCK_FILE"
        if ! flock -n 9; then
          log "Recovery already in progress, skipping duplicate request"
          return 0
        fi

        log "Starting recovery (reason=$reason)"
        wait_for_stable_topology >/dev/null || {
          log "Recovery aborted: topology did not stabilize"
          return 1
        }

        local workspace target
        for workspace in "''${MANAGED_WORKSPACES[@]}"; do
          target="$(target_for_workspace "$workspace")"
          if [[ -z "$target" ]]; then
            target="''${DEFAULT_TARGETS[$workspace]:-}"
          fi
          apply_mapping "$workspace" "$target"
        done

        apply_mapping "$HEADLESS_WORKSPACE" "''${DEFAULT_TARGETS[$HEADLESS_WORKSPACE]}"
        snapshot_state || true
        refresh_panel
        log "Recovery complete"
      }

      schedule_recover() {
        printf '%s\n' "$(date +%s)" > "$LAST_EVENT_FILE"

        if [[ -n "''${DEBOUNCE_PID:-}" ]] && kill -0 "$DEBOUNCE_PID" 2>/dev/null; then
          return 0
        fi

        (
          local observed latest
          while true; do
            observed="$(cat "$LAST_EVENT_FILE" 2>/dev/null || echo 0)"
            sleep "$DEBOUNCE_SECONDS"
            latest="$(cat "$LAST_EVENT_FILE" 2>/dev/null || echo 0)"
            [[ "$observed" == "$latest" ]] && break
          done
          "$0" recover --reason socket >/dev/null 2>&1 || true
        ) &
        DEBOUNCE_PID=$!
      }

      watch() {
        have_hyprland_env || {
          log "Watcher cannot start without HYPRLAND_INSTANCE_SIGNATURE"
          return 1
        }

        local socket="$SOCKET_PATH"
        log "Starting watcher on $socket"

        while true; do
          if [[ ! -S "$socket" ]]; then
            log "Socket not ready yet: $socket"
            sleep 2
            continue
          fi

          snapshot_state || true

          socat -u "UNIX-CONNECT:$socket" - 2>/dev/null | while read -r line; do
            case "$line" in
              monitoradded*|monitorremoved*|monitorrenamed*|configreloaded*)
                log "Event received: $line"
                schedule_recover
                ;;
              workspacev2*|focusedmonv2*)
                snapshot_state || true
                ;;
            esac
          done

          log "Socket stream ended, retrying"
          sleep 1
        done
      }

      case "''${1:-watch}" in
        watch)
          watch
          ;;
        recover)
          shift || true
          recover "$@"
          ;;
        snapshot)
          snapshot_state
          ;;
        *)
          echo "Usage: $0 [watch|recover|snapshot]" >&2
          exit 1
          ;;
      esac
    '';
  };
in
{
  # Home packages
  home.packages = [
    add_record_player
    hyprland_workspace_recovery
    # Thumbnail backend packages for tumbler
    pkgs.ffmpegthumbnailer  # video thumbnails
    pkgs.poppler            # PDF thumbnails
  ];

  # Hyprland Window Manager Configuration
  wayland.windowManager.hyprland = {
    enable = true;
    # portalPackage is managed via `xdg.portal` above so we don't set it here
    settings = {
      ecosystem = {
        no_update_news = true;
        no_donation_nag = true;
      };
      misc = {
        vrr = 2; # VRR only when fullscreen (prevents flicker on 60Hz side monitors)
      };
      cursor = {
        no_hardware_cursors = true;
      };
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
      # Window rules using v3 syntax (Hyprland 0.53+)
      windowrule = [
        # Picture-in-Picture rules
        "match:title Picture-in-Picture, float on"
        "match:title Picture-in-Picture, pin on"
        "match:title Picture-in-Picture, no_shadow on"
        "match:title Picture-in-Picture, size 25% 25%"
        "match:title Picture-in-Picture, move 100%-w-20"
        "match:title Picture-in-Picture, no_initial_focus on"
        # MPV rules
        "match:class mpv, float on"
        "match:class mpv, pin on"
        "match:class mpv, no_shadow on"
        "match:class mpv, size 50% 50%"
        "match:class mpv, move 100%-w-20"
        "match:class mpv, no_initial_focus on"
        # GLava rules
        "match:class GLava, float on"
        "match:class GLava, size 100% 25%"
        "match:class GLava, move 100%-w-20"
        "match:class GLava, no_shadow on"
        "match:title GLava, no_initial_focus on"
        # Browser opacity rules
        "match:class ^(chromium|Chromium|vivaldi|Vivaldi)$, opacity 1.0 override 1.0 override"
        "match:class ^(chromium|Chromium|vivaldi|Vivaldi)$, no_blur on"
        # Gaming window rules - Steam client
        "match:class ^steam$, float on"
        "match:class ^steam$ title:^Steam$, workspace 1"
        # Gaming window rules - games launched via Steam/Proton
        "match:class ^steam_app_, workspace 5"
        "match:class ^steam_app_, fullscreen 1"
        "match:class ^steam_app_, no_blur on"
        "match:class ^steam_app_, no_shadow on"
        "match:class ^steam_app_, immediate on"
        # Gamescope window rules
        "match:class ^gamescope$, fullscreen 1"
        "match:class ^gamescope$, no_blur on"
        "match:class ^gamescope$, no_shadow on"
        "match:class ^gamescope$, immediate on"
      ];
      monitor = [
        # Bottom row - Three Dell monitors at y=2160
        "${vars.tertiaryMonitor.name},${toString vars.tertiaryMonitor.width}x${toString vars.tertiaryMonitor.height}@${toString vars.tertiaryMonitor.refresh},5900x2160,1"  # Left Dell
        "${vars.mainMonitor.name},${toString vars.mainMonitor.width}x${toString vars.mainMonitor.height}@${toString vars.mainMonitor.refresh},7820x2160,1"      # Middle Dell (Main)
        "${vars.secondaryMonitor.name},${toString vars.secondaryMonitor.width}x${toString vars.secondaryMonitor.height}@${toString vars.secondaryMonitor.refresh},10380x2160,1"  # Right Dell
        # Top row - Samsung monitor centered above middle
        "${vars.fourthMonitor.name},${toString vars.fourthMonitor.width}x${toString vars.fourthMonitor.height}@${toString vars.fourthMonitor.refresh},8140x1080,1"  # Samsung (Top)
        # Headless monitor for Sunshine streaming (not visible on physical displays)
        "HEADLESS-1,2160x1440@60,auto,1"
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
        "99,monitor:HEADLESS-1,default:true"
      ];
      env = [
        "LIBVA_DRIVER_NAME,nvidia"
        "__GLX_VENDOR_LIBRARY_NAME,nvidia"
        "NVD_BACKEND,direct"
        "XDG_SESSION_TYPE,wayland"
        "GBM_BACKEND,nvidia-drm"
        "__GL_GSYNC_ALLOWED,1"
        "__GL_VRR_ALLOWED,1"
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
        "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
        "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1"
        "hyprctl output create headless HEADLESS-1"
        "add_record_player"
        "blueman-applet"
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
        "$mod ALT, H, resizeactive, -80 0"
        "$mod ALT, L, resizeactive, 80 0"
        "$mod ALT, K, resizeactive, 0 -80"
        "$mod ALT, J, resizeactive, 0 80"
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

  systemd.user.services.hyprland-workspace-recovery = {
    Unit = {
      Description = "Watch Hyprland monitor events and recover workspace mapping";
      After = [ "graphical-session.target" "hyprland-session.target" ];
      BindsTo = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      Wants = [ "hyprland-session.target" ];
    };
    Service = {
      ExecStart = "${hyprland_workspace_recovery}/bin/hyprland-workspace-recovery watch";
      Restart = "always";
      RestartSec = "2s";
      Environment = [
        "XDG_CURRENT_DESKTOP=Hyprland"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.hyprland-workspace-recover-resume = {
    Unit = {
      Description = "Recover Hyprland workspaces after suspend/resume";
      After = [ "suspend.target" "graphical-session.target" "hyprland-session.target" ];
      BindsTo = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      Wants = [ "hyprland-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${hyprland_workspace_recovery}/bin/hyprland-workspace-recovery recover --reason resume";
      Environment = [
        "XDG_CURRENT_DESKTOP=Hyprland"
      ];
    };
    Install.WantedBy = [ "suspend.target" ];
  };
}
