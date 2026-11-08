# Hyprland multi-monitor workspace recovery (watch socket + suspend resume).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hyprland.workspaceRecovery;

  managedWorkspaces = lib.filter (w: builtins.hasAttr w cfg.mappings) [
    "1"
    "2"
    "3"
    "4"
    "5"
    "6"
    "7"
    "8"
    "9"
    "10"
  ];

  headlessWorkspace = "99";

  defaultTargetsBash = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (ws: target: ''["${ws}"]=${lib.escapeShellArg target}'') cfg.mappings
  );

  jqDefaultArgs = lib.concatStringsSep " \\\n          " (
    lib.mapAttrsToList (ws: target: ''--arg default_${ws} "${target}"'') cfg.mappings
  );

  jqDefaultObject = lib.concatStringsSep "\n                  " (
    lib.mapAttrsToList (ws: _target: ''"${ws}": $default_${ws},'') cfg.mappings
  );

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

      readonly -a MANAGED_WORKSPACES=(${lib.concatStringsSep " " (map (w: "\"${w}\"") managedWorkspaces)})
      readonly HEADLESS_WORKSPACE="${headlessWorkspace}"

      declare -Ar DEFAULT_TARGETS=(
      ${defaultTargetsBash}
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
          ${jqDefaultArgs} \
          '
          def stable_id_for_monitor($monitors; $name):
            ($monitors[] | select(.name == $name) |
              (if (.description // "") != "" then "desc:" + .description else .name end)
            );

          {
            created_at: $created_at,
            topology: $topology,
            mappings:
              reduce [${lib.concatStringsSep "," managedWorkspaces}][] as $ws (
                {
                  ${jqDefaultObject}
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

        if [[ -n "''${DEFAULT_TARGETS[$HEADLESS_WORKSPACE]:-}" ]]; then
          apply_mapping "$HEADLESS_WORKSPACE" "''${DEFAULT_TARGETS[$HEADLESS_WORKSPACE]}"
        fi
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
  options.hyprland.workspaceRecovery = {
    enable = lib.mkEnableOption "Hyprland workspace-to-monitor recovery on topology changes";

    mappings = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Workspace ID (string keys) to monitor identifier (Hyprland output name or desc:… stable id).
        Include workspace "99" for the headless output mapping when used.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.mappings != { };
        message = "hyprland.workspaceRecovery.enable requires non-empty mappings";
      }
    ];

    home.packages = [ hyprland_workspace_recovery ];

    systemd.user.services.hyprland-workspace-recovery = {
      Unit = {
        Description = "Watch Hyprland monitor events and recover workspace mapping";
        After = [
          "graphical-session.target"
          "hyprland-session.target"
        ];
        BindsTo = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        Wants = [ "hyprland-session.target" ];
        # Restart=always with a 2s interval; without a ceiling a persistently
        # failing watcher would respawn ~1800 times an hour.
        StartLimitIntervalSec = 300;
        StartLimitBurst = 10;
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
        After = [
          "suspend.target"
          "graphical-session.target"
          "hyprland-session.target"
        ];
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
  };
}
