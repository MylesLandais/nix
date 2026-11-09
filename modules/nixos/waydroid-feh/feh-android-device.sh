echo "== USB devices =="; lsusb
adb start-server >/dev/null
lines=$(adb devices -l | sed '1d;/^[[:space:]]*$/d')
if [ -z "$lines" ]; then
  if lsusb | grep -Eqi 'Samsung|Google|Android|Motorola|OnePlus|Xiaomi'; then
    echo "Android-like USB device present, but absent from ADB (check USB mode, debugging, and cable permissions)."; exit 2
  fi
  echo "No Android USB device detected."; exit 1
fi
echo "== ADB devices =="; printf '%s\n' "$lines"
if printf '%s\n' "$lines" | grep -q unauthorized; then echo "Unlock phone and accept the RSA prompt."; exit 3; fi
count=$(printf '%s\n' "$lines" | grep -c '[[:space:]]device[[:space:]]' || true)
[ "$count" -eq 1 ] || { echo "Expected exactly one authorized device; found $count."; exit 4; }
serial=$(printf '%s\n' "$lines" | awk '$2 == "device" {print $1}')
echo "Authorized serial: $serial"
adb -s "$serial" shell getprop ro.product.model
adb -s "$serial" shell dumpsys package @NIX1@ 2>/dev/null | grep -E 'version(Name|Code)=' || echo "FEH is not installed or package metadata is inaccessible."
