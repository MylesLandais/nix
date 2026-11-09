seconds="${1:-300}"
case "$seconds" in *[!0-9]*|"") echo "duration must be seconds" >&2; exit 2;; esac
out="${XDG_STATE_HOME:-$HOME/.local/state}/feh-waydroid/tests/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$out"
waydroid status >"$out/status.txt" 2>&1 || true
sudo waydroid shell -- logcat -c || true
waydroid session start >/dev/null 2>&1 &
sleep 3
waydroid app launch @NIX1@ || true
echo "Capture running for $seconds seconds; exercise title screen and one guest battle."
sleep "$seconds"
sudo waydroid shell -- screencap -p /sdcard/feh-test.png || true
# Redirects are intentionally performed by this unprivileged evidence collector.
# shellcheck disable=SC2024
sudo waydroid shell -- cat /sdcard/feh-test.png >"$out/screenshot.png" 2>/dev/null || true
# shellcheck disable=SC2024
sudo waydroid shell -- dumpsys package @NIX2@ >"$out/package.txt" 2>&1 || true
# shellcheck disable=SC2024
sudo waydroid shell -- dumpsys activity activities >"$out/activity.txt" 2>&1 || true
# shellcheck disable=SC2024
sudo waydroid shell -- logcat -d >"$out/logcat.txt" 2>&1 || true
if grep -Eqi 'FATAL EXCEPTION|SIG(SEGV|ABRT)|Process com\.nintendo\.zaba .* died' "$out/logcat.txt"; then verdict=FAIL-CRASH; else verdict=PASS-PENDING-VISUAL; fi
printf '%s\n' "$verdict" | tee "$out/verdict.txt"
echo "Evidence: $out"
