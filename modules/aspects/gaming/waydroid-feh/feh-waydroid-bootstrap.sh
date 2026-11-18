if [ "$EUID" -ne 0 ]; then echo "run with sudo" >&2; exit 1; fi
if [ -f /var/lib/waydroid/waydroid.cfg ]; then
  if grep -Eqi 'system_ota.*(gapps|google)' /var/lib/waydroid/waydroid.cfg; then
    echo "Existing GAPPS Waydroid installation retained."
    exit 0
  fi
  echo "Refusing to overwrite existing Waydroid state at /var/lib/waydroid." >&2
  echo "Inspect it manually; no data was changed." >&2
  exit 1
fi
waydroid init -s GAPPS -f
waydroid prop set persist.waydroid.width @NIX1@
waydroid prop set persist.waydroid.height @NIX2@
waydroid prop set persist.waydroid.multi_windows true
echo "Initialized Android GAPPS. Start with: feh-waydroid ui"
