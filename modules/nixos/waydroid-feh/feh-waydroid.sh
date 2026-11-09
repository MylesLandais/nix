set -euo pipefail
action="${1:-ui}"
shift || true

start_session() {
  waydroid session start >/dev/null 2>&1 &
  for _ in $(seq 1 45); do
    if waydroid status 2>/dev/null | grep -q 'Session:[[:space:]]*RUNNING'; then
      return 0
    fi
    sleep 2
  done
  echo "Waydroid did not become ready within 90 seconds." >&2
  return 1
}

ensure_portrait_session() {
  configured_width=$(waydroid prop get persist.waydroid.width 2>/dev/null || true)
  configured_height=$(waydroid prop get persist.waydroid.height 2>/dev/null || true)
  start_session
  waydroid prop set persist.waydroid.width @NIX1@
  waydroid prop set persist.waydroid.height @NIX2@
  waydroid prop set persist.waydroid.multi_windows true

  if [ "$configured_width" != "@NIX3@" ] || [ "$configured_height" != "@NIX4@" ]; then
    echo "Restarting Waydroid to apply @NIX5@x@NIX6@ portrait geometry."
    waydroid session stop
    start_session
  fi
}

case "$action" in
  ui) waydroid show-full-ui "$@" ;;
  stop) waydroid session stop || true ;;
  status) waydroid status ;;
  store)
    start_session
    waydroid app launch com.android.vending
    ;;
  install)
    xdg-open "https://play.google.com/store/apps/details?id=@NIX7@"
    waydroid session start >/dev/null 2>&1 &
    sleep 3
    waydroid app launch com.android.vending
    ;;
  play)
    ensure_portrait_session
    waydroid app launch @NIX8@
    ;;
  shell) exec waydroid shell "$@" ;;
  *) echo "usage: feh-waydroid {ui|stop|status|store|install|play|shell}" >&2; exit 2 ;;
esac
