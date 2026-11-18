prefix_dir=@NIX1@
game_name=@NIX2@
lutris_games_dir="${XDG_CONFIG_HOME:-$HOME/.config}/lutris/games"
legacy_lutris_games_dir="${XDG_DATA_HOME:-$HOME/.local/share}/lutris/games"

usage() {
  cat <<'EOF'
Usage: @NIX3@ [install|play|status|debug|help]

  install  bootstrap Battle.net or register the configured shared prefix
  play     launch @NIX4@ through Lutris and GameMode
  status   report Battle.net prefix and Lutris registration state
  debug    launch @NIX5@ with Lutris debug logging

With no command, the launcher installs/registers when needed, then plays.
@NIX6@
EOF
}

battle_net_exe() {
  for candidate in \
    "$prefix_dir/drive_c/Program Files (x86)/Battle.net/Battle.net.exe" \
    "$prefix_dir/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
  do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

registration_file() {
  for games_dir in "$lutris_games_dir" "$legacy_lutris_games_dir"; do
    if [ -d "$games_dir" ]; then
      registration=$(find "$games_dir" -maxdepth 1 -type f \
        -iname @NIX7@ -print -quit 2>/dev/null || true)
      if [ -n "$registration" ]; then
        printf '%s\n' "$registration"
        return 0
      fi
    fi
  done
  return 1
}

install_game() {
  if registration=$(registration_file); then
    echo "$game_name is already registered: $registration"
    return 0
  fi

  mkdir -p -- "$(dirname "$prefix_dir")"
  if client=$(battle_net_exe); then
    echo "Registering the existing Battle.net client: $client"
    exec lutris -i @NIX8@
  fi

  if [ -d "$prefix_dir" ]; then
    echo "Reusing the existing partial prefix without deleting it: $prefix_dir"
  else
    echo "Creating the shared Battle.net prefix: $prefix_dir"
  fi
  exec lutris -i @NIX9@
}

require_registration() {
  if ! registration_file >/dev/null; then
    echo "$game_name is not registered; run: @NIX10@ install" >&2
    exit 1
  fi
}

show_status() {
  failed=0
  echo "prefix: $prefix_dir"
  if client=$(battle_net_exe); then
    echo "Battle.net: present ($client)"
  else
    echo "Battle.net: missing"
    failed=1
  fi
  if registration=$(registration_file); then
    echo "Lutris entry: present ($registration)"
  else
    echo "Lutris entry: missing"
    failed=1
  fi
  return "$failed"
}

action="${1:-open}"
case "$action" in
  open)
    if registration_file >/dev/null; then
      exec gamemoderun lutris lutris:rungame/@NIX11@
    else
      install_game
    fi
    ;;
  install) install_game ;;
  play)
    require_registration
    exec gamemoderun lutris lutris:rungame/@NIX12@
    ;;
  status) show_status ;;
  debug)
    require_registration
    exec gamemoderun lutris --debug lutris:rungame/@NIX13@
    ;;
  help|-h|--help) usage ;;
  *)
    echo "Unknown command: $action" >&2
    usage >&2
    exit 2
    ;;
esac
