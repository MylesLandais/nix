#!/usr/bin/env bash
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
bash -n "$repo/scripts/desktop-session-audit.sh" "$repo/scripts/warcraft3-linux-audit.sh"
td="$(mktemp -d)"
trap 'rm -rf "$td"' EXIT
mkdir -p "$td/user/applications" "$td/sys/applications" "$td/user/autostart"
printf '[Desktop Entry]\nType=Application\nName=Test\nExec=test\n' > "$td/user/applications/test.desktop"
cp "$td/user/applications/test.desktop" "$td/sys/applications/test.desktop"
printf '[Desktop Entry]\nType=Application\nName=Missing\nExec=missing\nTryExec=/does/not/exist\n' > "$td/user/autostart/missing.desktop"
XDG_DATA_HOME="$td/user" XDG_DATA_DIRS="$td/sys" XDG_CONFIG_HOME="$td/user" \
  XDG_CONFIG_DIRS="$td/no-config" "$repo/scripts/desktop-session-audit.sh" > "$td/out"
grep -q 'SHADOWED applications' "$td/out"
grep -q 'STALE' "$td/out"
grep -q 'Scanned 3 entries; 1 shadowed IDs;' "$td/out"
echo 'PASS: syntax, desktop precedence and stale launcher detection'
