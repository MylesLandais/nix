prefix_dir=@NIX1@
export PROTONPATH=@NIX2@

drive_c="$prefix_dir/drive_c"
battle_net_exe="$drive_c/Program Files (x86)/Battle.net/Battle.net.exe"
game_exe="$drive_c/Program Files (x86)/Warcraft III/_retail_/x86_64/Warcraft III.exe"
# Proton runs everything as "steamuser"; this is the file the client reads.
battle_net_config="$drive_c/users/steamuser/AppData/Roaming/Battle.net/Battle.net.config"
battle_net_logs="$drive_c/users/steamuser/AppData/Local/Battle.net/Logs"
state_dir="${XDG_RUNTIME_DIR:-/tmp}/warcraft3-reforged"
mkdir -p -- "$state_dir"

usage() {
  cat <<'EOF'
Usage: warcraft3-reforged [play|prewarm|battlenet|stop|install|status|debug|help]

  play       launch WC3 through Battle.net without pressing Play; reuses a
             running (pre-warmed) client, otherwise starts one and waits
             for its sign-in
  prewarm    start Battle.net hidden and signed in, ready for a fast play
  battlenet  show the Battle.net client (patches, settings, sign-in)
  stop       end the Battle.net/WC3 Wine session
  install    install Battle.net into the prefix, then sign in and install WC3
  status     report prefix, Proton, session, and ntsync state
  debug      like play, with a Proton log written to the prefix

With no command, the launcher installs when needed, then plays.
The command is also available as: wc3
EOF
}

use_proton() {
  if [ ! -x "$PROTONPATH/proton" ]; then
    echo "Proton build not found: $PROTONPATH" >&2
    exit 1
  fi
  if [ "${DISPLAY:-}" = ":0" ] && [ ! -S /tmp/.X11-unix/X0 ]; then
    # Without the X0 socket Wine falls back to its Wayland driver,
    # where the WC3 menu renders black.
    echo "warning: /tmp/.X11-unix/X0 is missing; WC3 will likely render black" >&2
  fi
  export WINEPREFIX="$prefix_dir"
  export GAMEID="umu-$1"
  # Lets a later umu-run re-enter the running container, so a second
  # --exec reaches the signed-in client instead of starting another.
  export UMU_CONTAINER_NSENTER=1
  # Controller-navigation helper; GE enables it by default and it
  # starts two extra .NET processes per launch.
  export PROTON_USE_XALIA=0
  # Keeps DXVK reporting the real NVIDIA adapter, as under Lutris.
  export PROTON_ENABLE_NVAPI=1
  # Skip the per-launch network check for Steam Runtime updates.
  export UMU_RUNTIME_UPDATE=0
  export WINEDLLOVERRIDES="locationapi=d${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
  export __GL_SHADER_DISK_CACHE=1
  export __GL_SHADER_DISK_CACHE_PATH="$prefix_dir"
  export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
}

# Prints the PID of the first Wine process in this prefix whose
# Windows command line matches $1 (helper processes excluded).
wine_pid() {
  local pid args
  while read -r pid args; do
    case "$args" in C:\\*) ;; *) continue ;; esac
    case "$args" in *--type=*) continue ;; esac
    [[ "$args" =~ $1 ]] || continue
    if grep -qzE "^WINEPREFIX=$prefix_dir(/|$)" "/proc/$pid/environ" 2>/dev/null; then
      printf '%s\n' "$pid"
      return 0
    fi
  done < <(ps -eo pid=,args=)
  return 1
}
client_running() { wine_pid 'Battle\.net\\Battle\.net\.exe' >/dev/null; }
game_running() { wine_pid 'Warcraft III\.exe' >/dev/null; }

# True once the client started by this session has signed in.
signed_in() {
  local log
  [ -f "$state_dir/session-start" ] || return 1
  while read -r log; do
    grep -q 'Logged into Battle.net successfully' "$log" && return 0
  done < <(find "$battle_net_logs" -maxdepth 1 -name 'battle.net-*.log' -newer "$state_dir/session-start" 2>/dev/null)
  return 1
}

wait_for() {
  local check=$1 seconds=$2
  for _ in $(seq 1 "$((seconds * 2))"); do
    "$check" && return 0
    sleep 0.5
  done
  return 1
}

seed_battle_net_config() {
  [ -f "$battle_net_config" ] && return 0
  mkdir -p -- "$(dirname "$battle_net_config")"
  cat >"$battle_net_config" <<'EOF'
{
    "Client": {
        "GameLaunchWindowBehavior": "2",
        "HardwareAcceleration": "false",
        "Sound": { "Enabled": "false" },
        "Streaming": { "StreamingEnabled": "false" }
    }
}
EOF
}

# Starts the Battle.net session. $1 is the umu GAMEID suffix, which
# sets the window class; $2=foreground keeps it attached (systemd).
start_client() {
  seed_battle_net_config
  use_proton "$1"
  touch "$state_dir/session-start"
  if [ "${2:-}" = foreground ]; then
    gamemoded -r"$$" >/dev/null 2>&1 || true
    exec umu-run "$battle_net_exe"
  fi
  setsid umu-run "$battle_net_exe" >"$state_dir/umu.log" 2>&1 </dev/null &
  # GameMode's LD_PRELOAD can't find libgamemode inside the Steam
  # Runtime container, so register the host-side umu process instead;
  # it lives for the whole session.
  gamemoded -r"$!" >/dev/null 2>&1 || true
}

show_hidden_client() {
  command -v hyprctl >/dev/null &&
    hyprctl eval 'hl.dsp.workspace.toggle_special("battlenet")' >/dev/null 2>&1 || true
}

play() {
  if game_running; then
    echo "@NIX3@ is already running."
    return 0
  fi
  if ! client_running; then
    start_client @NIX4@
  fi
  if ! wait_for signed_in 120; then
    show_hidden_client
    echo "Battle.net has not signed in; sign in there, then run: warcraft3-reforged" >&2
    exit 1
  fi
  sleep 3
  # Battle.net ignores --exec on its own cold start, but honours it
  # from a second instance once signed in.
  for _ in 1 2 3; do
    use_proton @NIX5@
    umu-run "$battle_net_exe" --exec="launch W3" >>"$state_dir/umu.log" 2>&1 </dev/null &
    wait_for game_running 15 && return 0
  done
  echo "Battle.net did not start the game; press Play in the client." >&2
  show_hidden_client
  exit 1
}

stop_session() {
  local pid args killed=0
  while read -r pid args; do
    case "$args" in [Cc]:*) ;; *) continue ;; esac
    if grep -qzE "^WINEPREFIX=$prefix_dir(/|$)" "/proc/$pid/environ" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null && killed=$((killed + 1))
    fi
  done < <(ps -eo pid=,args=)
  rm -f -- "$state_dir/session-start"
  echo "Stopped $killed Wine processes."
}

install_battle_net() {
  if [ -f "$battle_net_exe" ]; then
    echo "Battle.net is already installed: $battle_net_exe"
    return 0
  fi
  mkdir -p -- "$prefix_dir"
  seed_battle_net_config
  setup="${XDG_CACHE_HOME:-$HOME/.cache}/warcraft3-reforged/Battle.net-Setup.exe"
  mkdir -p -- "$(dirname "$setup")"
  curl -fL --retry 3 -o "$setup" \
    'https://www.battle.net/download/getInstallerForGame?os=win&version=LIVE&gameProgram=BATTLENET_APP'
  use_proton @NIX6@
  echo "Installing Battle.net. Sign in, then install @NIX7@ from the client."
  exec umu-run "$setup"
}

show_status() {
  failed=0
  echo "prefix: $prefix_dir"
  if [ -x "$PROTONPATH/proton" ]; then
    echo "Proton: $(cat "$PROTONPATH/version" 2>/dev/null || echo present) ($PROTONPATH)"
  else
    echo "Proton: missing ($PROTONPATH)"
    failed=1
  fi
  if [ -f "$battle_net_exe" ]; then echo "Battle.net: installed"; else echo "Battle.net: missing"; failed=1; fi
  if [ -f "$game_exe" ]; then echo "Warcraft III: installed"; else echo "Warcraft III: missing"; failed=1; fi
  if client_running; then
    if signed_in; then echo "session: Battle.net running, signed in"; else echo "session: Battle.net running, not signed in"; fi
  else
    echo "session: no Battle.net client"
  fi
  if game_running; then echo "game: running"; fi
  if [ -c /dev/ntsync ]; then
    echo "ntsync: available"
  else
    echo "ntsync: missing (Proton falls back to fsync)"
  fi
  return "$failed"
}

action="${1:-open}"
case "$action" in
  open)
    if [ -f "$game_exe" ]; then
      play
    elif [ -f "$battle_net_exe" ]; then
      client_running || start_client @NIX8@
    else
      install_battle_net
    fi
    ;;
  play) play ;;
  prewarm)
    if client_running; then
      echo "Battle.net is already running."
    elif [ -n "${WC3_FOREGROUND:-}" ]; then
      start_client @NIX9@ foreground
    else
      start_client @NIX10@
    fi
    ;;
  battlenet)
    if client_running; then show_hidden_client; else start_client @NIX11@; fi
    ;;
  stop) stop_session ;;
  install) install_battle_net ;;
  status) show_status ;;
  debug)
    export PROTON_LOG=1
    export PROTON_LOG_DIR="$prefix_dir"
    echo "Proton log: $prefix_dir/steam-*.log"
    play
    ;;
  help|-h|--help) usage ;;
  *)
    echo "Unknown command: $action" >&2
    usage >&2
    exit 2
    ;;
esac
