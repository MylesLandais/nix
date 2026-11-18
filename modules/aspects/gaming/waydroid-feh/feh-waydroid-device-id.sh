id=$(sudo waydroid shell -- sh -c "sqlite3 /data/data/com.google.android.gsf/databases/gservices.db 'select value from main where name=\"android_id\";'" | tr -d '\r')
if [ -z "$id" ]; then echo "No GSF ID found; start Android and finish initial setup first." >&2; exit 1; fi
printf 'GSF ID: %s\n' "$id"
xdg-open https://www.google.com/android/uncertified/ >/dev/null 2>&1 || true
