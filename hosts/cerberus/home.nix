{
  pkgs,
  lib,
  vars,
  config,
  inputs,
  ...
}:
let
  vesktopSafe = pkgs.writeShellApplication {
    name = "vesktop";
    runtimeInputs = [ pkgs.vesktop ];
    text = ''
      exec ${lib.getExe pkgs.vesktop} \
        --disable-gpu-sandbox \
        --ozone-platform-hint=auto \
        "$@"
    '';
  };

  cursorSafe = pkgs.writeShellApplication {
    name = "cursor";
    runtimeInputs = [ pkgs.code-cursor ];
    text = ''
      # Cerberus: native Wayland + GPU on NVIDIA (RTX 3090 Ti, driver 610+).
      # GPU/hw-accel stays ON for performance, but using desktop GL instead of
      # Vulkan ANGLE: native-Wayland + Vulkan crashed the GPU context under agent
      # load. Dropped WaylandLinuxDrmSyncobj/VaapiVideoDecoder for the same reason.
      export __GLX_VENDOR_LIBRARY_NAME=nvidia
      export GBM_BACKEND=nvidia-drm
      export LIBVA_DRIVER_NAME=nvidia
      export GDK_BACKEND=wayland

      exec ${pkgs.code-cursor}/bin/cursor \
        --ozone-platform=wayland \
        --enable-features=UseOzonePlatform,WaylandWindowDecorations \
        --use-angle=gl \
        --enable-wayland-ime \
        --js-flags=--max-old-space-size=8192 \
        "$@"
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
  imports = [
    ../../modules/features/hydra-smb.nix
  ];

  hydra-smb.enable = true;

  home.packages = [
    (lib.hiPrio vesktopSafe)
    (lib.hiPrio cursorSafe)
    hyprland_workspace_recovery
    inputs.llm.packages.${pkgs.system}.cursor-agent
  ];

  xdg.desktopEntries.vesktop = {
    name = "Vesktop";
    genericName = "Internet Messenger";
    exec = "${vesktopSafe}/bin/vesktop %U";
    icon = "vesktop";
    terminal = false;
    categories = [
      "Network"
      "InstantMessaging"
      "Chat"
    ];
    mimeType = [ "x-scheme-handler/discord" ];
  };

  xdg.desktopEntries.cursor = {
    name = "Cursor";
    genericName = "Text Editor";
    exec = "${cursorSafe}/bin/cursor %F";
    icon = "cursor";
    terminal = false;
    categories = [
      "Utility"
      "TextEditor"
      "Development"
      "IDE"
    ];
    mimeType = [ "application/x-cursor-workspace" ];
  };

  xdg.desktopEntries.cursor-url-handler = {
    name = "Cursor - URL Handler";
    exec = "${cursorSafe}/bin/cursor --open-url %U";
    icon = "cursor";
    terminal = false;
    noDisplay = true;
    mimeType = [ "x-scheme-handler/cursor" ];
  };

  # Hardware acceleration re-enabled: the SIGILL crashes were a 550-era NVIDIA bug,
  # fixed on driver 610+. Forcing this off was what made the agent window CPU-render
  # (use-gl=disabled) and feel sluggish. The wrapper above runs native Wayland + Vulkan.
  home.file."${config.xdg.configHome}/Cursor/argv.json".text =
    builtins.toJSON {
      disable-hardware-acceleration = false;
    };

  xdg.configFile."hypr/hyprland.conf" = {
    force = true;
    text = ''
      autogenerated = 1
    '';
  };

  wayland.windowManager.hyprland.extraConfig = lib.mkAfter (
    let
      m = vars;
    in
    ''
      -- == Cerberus monitors ==
      hl.monitor({ output = "${m.tertiaryMonitor.name}", mode = "${toString m.tertiaryMonitor.width}x${toString m.tertiaryMonitor.height}@${toString m.tertiaryMonitor.refresh}", position = "5900x2160", scale = 1 })
      hl.monitor({ output = "${m.mainMonitor.name}",     mode = "${toString m.mainMonitor.width}x${toString m.mainMonitor.height}@${toString m.mainMonitor.refresh}",         position = "7820x2160", scale = 1 })
      hl.monitor({ output = "${m.secondaryMonitor.name}", mode = "${toString m.secondaryMonitor.width}x${toString m.secondaryMonitor.height}@${toString m.secondaryMonitor.refresh}", position = "10380x2160", scale = 1 })
      hl.monitor({ output = "${m.fourthMonitor.name}",   mode = "${toString m.fourthMonitor.width}x${toString m.fourthMonitor.height}@${toString m.fourthMonitor.refresh}",     position = "8140x1080",  scale = 1 })
      hl.monitor({ output = "HEADLESS-1", mode = "2160x1440@60", position = "auto", scale = 1 })

      -- == Cerberus workspace pins ==
      hl.workspace_rule({ workspace = "1",  monitor = "${m.tertiaryMonitor.name}",  default = true })
      hl.workspace_rule({ workspace = "2",  monitor = "${m.mainMonitor.name}",      default = true })
      hl.workspace_rule({ workspace = "3",  monitor = "${m.secondaryMonitor.name}", default = true })
      hl.workspace_rule({ workspace = "4",  monitor = "${m.tertiaryMonitor.name}" })
      hl.workspace_rule({ workspace = "5",  monitor = "${m.mainMonitor.name}" })
      hl.workspace_rule({ workspace = "6",  monitor = "${m.secondaryMonitor.name}" })
      hl.workspace_rule({ workspace = "7",  monitor = "${m.tertiaryMonitor.name}" })
      hl.workspace_rule({ workspace = "8",  monitor = "${m.mainMonitor.name}" })
      hl.workspace_rule({ workspace = "9",  monitor = "${m.secondaryMonitor.name}" })
      hl.workspace_rule({ workspace = "10", monitor = "${m.fourthMonitor.name}",    default = true })
      hl.workspace_rule({ workspace = "99", monitor = "HEADLESS-1",                 default = true })

      -- == Cerberus env ==
      hl.env("LIBVA_DRIVER_NAME", "nvidia")
      hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
      hl.env("NVD_BACKEND", "direct")
      hl.env("XDG_SESSION_TYPE", "wayland")
      hl.env("GBM_BACKEND", "nvidia-drm")
      hl.env("__GL_GSYNC_ALLOWED", "1")
      hl.env("__GL_VRR_ALLOWED", "1")
      hl.env("WLR_NO_HARDWARE_CURSORS", "1")
      hl.env("NIXOS_OZONE_WL", "1")
      hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
      hl.env("QT_QPA_PLATFORM", "wayland;xcb")
      hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
      hl.env("XDG_SESSION_DESKTOP", "Hyprland")
      hl.env("XDG_CONFIG_HOME", "${config.xdg.configHome}")
      hl.env("BROWSER", "Firefox")
      hl.env("GTK_USE_PORTAL", "1")
      hl.env("XCURSOR_SIZE", "22")
      hl.env("EDITOR", "nvim")
      -- == Cerberus overrides (VRR, cursor, ecosystem) ==
      hl.config({
        misc = {
          vrr = 2,
        },
        cursor = {
          no_hardware_cursors = true,
        },
        ecosystem = {
          no_update_news = true,
          no_donation_nag = true,
        },
      })

      -- == Cerberus startup ==
      hl.on("hyprland.start", function()
        hl.exec_cmd("systemctl --user start gnome-keyring.service")
        hl.exec_cmd("systemctl --user start gvfs-daemon.service")
        hl.exec_cmd("dbus-update-activation-environment --systemd DISPLAY HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_RUNTIME_DIR DBUS_SESSION_BUS_ADDRESS SSH_AUTH_SOCK && systemctl --user stop hyprland-session.target && systemctl --user start hyprland-session.target")
        hl.exec_cmd("${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1")
        hl.exec_cmd("hyprctl output create headless HEADLESS-1")
        hl.exec_cmd("blueman-applet")
        -- GVfs Hydra mount after keyring (restores pre-2e9e10b hypr.nix session ordering)
        hl.exec_cmd("systemctl --user start mount-hydra.service")
      end)
    ''
  );

  services.hyprpaper.settings = {
    preload = lib.mkForce [ vars.wallpaper ];
    wallpaper = lib.mkForce [
      "${vars.mainMonitor.name},${vars.wallpaper}"
      "${vars.secondaryMonitor.name},${vars.wallpaper}"
      "${vars.tertiaryMonitor.name},${vars.wallpaper}"
      "${vars.fourthMonitor.name},${vars.wallpaper}"
    ];
  };

  # Helium with CDP debug port -- enables Chrome DevTools Protocol access
  # for Hermes agent to read tabs and capture page content.
  home.file.".local/share/applications/helium-browser-cdp.desktop".text = ''
      [Desktop Entry]
      Version=1.0
      Name=Helium (CDP)
      GenericName=Web Browser
      Comment=Helium with remote debugging for automation
      Exec=helium --remote-debugging-port=9222 %U
      StartupNotify=true
      Terminal=false
      Icon=helium
      Type=Application
      Categories=Network;WebBrowser;
      MimeType=text/html;x-scheme-handler/http;x-scheme-handler/https;x-scheme-handler/ftp;x-scheme-handler/unknown;application/xhtml+xml;application/xml;
    '';

  # Hermes ACP agent in the app launcher -- opens the CLI agent in a ghostty terminal.
  home.file.".local/share/applications/hermes.desktop".text = ''
      [Desktop Entry]
      Version=1.0
      Type=Application
      Name=Hermes (Terminal)
      GenericName=AI Agent
      Comment=Hermes ACP terminal agent
      Exec=ghostty -e hermes
      Terminal=false
      Icon=utilities-terminal
      Categories=Development;Utility;
    '';

  # Hermes GUI desktop app -- Electron wrapper around the same hermes CLI agent.
  home.file.".local/share/applications/hermes-desktop.desktop".text = ''
      [Desktop Entry]
      Version=1.0
      Type=Application
      Name=Hermes Desktop
      GenericName=AI Agent
      Comment=Hermes GUI desktop app
      Exec=hermes-desktop
      Terminal=false
      Icon=utilities-terminal
      Categories=Development;Utility;
    '';

  # Helium policy force-install uses the CWS update URL, which Helium rewrites to
  # its /ext proxy. Without ext_proxy enabled, CRX fetch fails (policy reason 25).
  # vertical_tabs.enabled must be true for the side tab strip (flags alone are not enough).
  home.activation.ensureHeliumProfilePrefs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    pref="$HOME/.config/net.imput.helium/Default/Preferences"
    if [ -f "$pref" ]; then
      ${pkgs.python3}/bin/python3 - "$pref" <<'PY'
import json, pathlib, sys
p = pathlib.Path(sys.argv[1])
data = json.loads(p.read_text())
changed = False

services = data.setdefault("helium", {}).setdefault("services", {})
for key, value in {"enabled": True, "ext_proxy": True, "consented": True}.items():
    if services.get(key) is not value:
        services[key] = value
        changed = True

vt = data.setdefault("vertical_tabs", {})
for key, value in {
    "enabled": True,
    "collapsed_state": False,
    "uncollapsed_width": 200,
}.items():
    if vt.get(key) is not value:
        vt[key] = value
        changed = True

if changed:
    p.write_text(json.dumps(data, separators=(",", ":")))
    print("Helium: updated profile prefs (ext_proxy, vertical_tabs.enabled)")
PY
    fi
  '';

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
      Environment = [ "XDG_CURRENT_DESKTOP=Hyprland" ];
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
      Environment = [ "XDG_CURRENT_DESKTOP=Hyprland" ];
    };
    Install.WantedBy = [ "suspend.target" ];
  };
}
