# Bring prompts to the screen in use.
#
# Bitwarden's SSH-agent approval and unlock prompts raise the Bitwarden window
# wherever it last lived; on Cerberus that is often workspace 10 on the TV,
# which is usually off. This watcher listens on Hyprland's event socket and,
# when a matching window opens or asks for attention on a workspace other than
# the focused monitor's, moves it to the focused workspace and focuses it.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.hyprland.promptFollowFocus;

  watcher = pkgs.writeShellApplication {
    name = "hyprland-prompt-follow-focus";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      socat
    ];
    text = ''
      readonly SOCKET="''${XDG_RUNTIME_DIR}/hypr/''${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
      readonly CLASSES=${lib.escapeShellArg cfg.classRegex}

      bring() {
        local address="0x$1" client focused
        client="$(hyprctl clients -j | jq -c --arg a "$address" '.[] | select(.address == $a)')" || return 0
        [[ -n "$client" ]] || return 0
        jq -e --arg re "$CLASSES" '.class | test($re; "i")' <<<"$client" >/dev/null || return 0
        focused="$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .activeWorkspace.id')"
        if [[ "$(jq -r '.workspace.id' <<<"$client")" != "$focused" ]]; then
          hyprctl dispatch movetoworkspacesilent "$focused,address:$address" >/dev/null
        fi
        hyprctl dispatch focuswindow "address:$address" >/dev/null
      }

      socat -U - "UNIX-CONNECT:$SOCKET" | while IFS= read -r line; do
        case "$line" in
          # A failed lookup or dispatch skips the event, never the watcher.
          urgent\>\>*) bring "''${line#urgent>>}" || true ;;
          openwindow\>\>*) rest="''${line#openwindow>>}"; bring "''${rest%%,*}" || true ;;
        esac
      done
    '';
  };
in
{
  options.hyprland.promptFollowFocus = {
    enable = lib.mkEnableOption "moving prompt windows to the focused workspace";
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
