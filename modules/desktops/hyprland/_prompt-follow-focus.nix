# Bring prompts to the screen in use.
#
# Bitwarden's SSH-agent approval and unlock prompts raise the Bitwarden window
# wherever it last lived; on Cerberus that is often workspace 10 on the TV,
# which is usually off. This watcher listens on Hyprland's event socket and,
# when a matching window opens, becomes active, or asks for attention, moves
# it to a visible workspace on an allowed office monitor.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.hyprland.promptFollowFocus;

  watcher = pkgs.writeShellApplication {
    name = "hyprland-prompt-follow-focus";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      socat
    ];
    text = ''
      readonly SOCKET="''${XDG_RUNTIME_DIR}/hypr/''${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
      readonly MONITORS=${lib.escapeShellArg (builtins.toJSON cfg.monitorDescriptions)}
      readonly CLASSES=${lib.escapeShellArg cfg.classRegex}

      bring() {
        local address="0x''${1#0x}" client focused
        client="$(hyprctl clients -j | jq -c --arg a "$address" '.[] | select(.address == $a)')" || return 0
        [[ -n "$client" ]] || return 0
        jq -e --arg re "$CLASSES" '.class | test($re; "i")' <<<"$client" >/dev/null || return 0
        focused="$(hyprctl monitors -j | jq -r --argjson allowed "$MONITORS" '
          [.[] | select(.disabled != true and .dpmsStatus != false)
           | . as $m
           | select(($allowed | length) == 0 or ($allowed | index($m.description)) != null)]
          | sort_by([if .focused then 0 else 1 end,
                     .description as $d | ($allowed | index($d)) // 0])
          | .[0].activeWorkspace.id // empty')" || return 0
        [[ "$focused" =~ ^[0-9]+$ && "$address" =~ ^0x[0-9a-fA-F]+$ ]] || return 0
        if [[ "$(jq -r '.workspace.id' <<<"$client")" != "$focused" ]]; then
          hyprctl eval "hl.dispatch(hl.dsp.window.move({workspace = $focused, window = \"address:$address\", follow = false}))" >/dev/null || return 0
        fi
        # Avoid generating another focus event when handling activewindowv2.
        if [[ "$(hyprctl activewindow -j | jq -r '.address // empty')" != "$address" ]]; then
          hyprctl eval "hl.dispatch(hl.dsp.focus({window = \"address:$address\"}))" >/dev/null
        fi
      }

      socat -U - "UNIX-CONNECT:$SOCKET" | while IFS= read -r line; do
        case "$line" in
          # A failed lookup or dispatch skips the event, never the watcher.
          activewindowv2\>\>*) bring "''${line#activewindowv2>>}" || true ;;
          urgent\>\>*) bring "''${line#urgent>>}" || true ;;
          openwindow\>\>*) rest="''${line#openwindow>>}"; bring "''${rest%%,*}" || true ;;
        esac
      done
    '';
  };
in
{
  options.my.hyprland.promptFollowFocus = {
    enable = lib.mkEnableOption "moving prompt windows to the focused workspace";
    monitorDescriptions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Allowed monitor descriptions, in fallback preference order; empty allows all monitors.";
    };
    classRegex = lib.mkOption {
      type = lib.types.str;
      default = "^(bitwarden|polkit-gnome-authentication-agent-1|pinentry.*)$";
      description = "Window classes (case-insensitive regex) to bring to the focused workspace.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.hyprland-prompt-follow-focus = {
      Unit = {
        Description = "Move prompt windows to the focused Hyprland workspace";
        After = [
          "graphical-session.target"
          "hyprland-session.target"
        ];
        BindsTo = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        StartLimitIntervalSec = 300;
        StartLimitBurst = 10;
      };
      Service = {
        ExecStart = lib.getExe watcher;
        Restart = "always";
        RestartSec = "2s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
