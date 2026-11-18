serial="${1:-}"
if [ -z "$serial" ]; then
  mapfile -t devices < <(adb devices | awk '$2 == "device" {print $1}')
  [ "${#devices[@]}" -eq 1 ] || { echo "Pass SERIAL when exactly one device is not authorized." >&2; exit 2; }
  serial="${devices[0]}"
fi
out="${XDG_STATE_HOME:-$HOME/.local/state}/feh-waydroid/samsung/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$out"
adb -s "$serial" shell getprop >"$out/getprop.txt"
adb -s "$serial" shell dumpsys package @NIX1@ >"$out/feh-package.txt" 2>&1 || true
adb -s "$serial" shell monkey -p @NIX2@ -c android.intent.category.LAUNCHER 1 || true
echo "Use FEH Account Management to link the intended Nintendo Account. No private app data will be copied."
exec scrcpy --serial "$serial"
