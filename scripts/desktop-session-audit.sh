#!/usr/bin/env bash
# Read-only XDG desktop-entry and Hyprland session inventory.
set -euo pipefail
section() { printf '\n== %s ==\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

section 'Session environment'
printf 'XDG_SESSION_TYPE=%s\nXDG_CURRENT_DESKTOP=%s\nXDG_SESSION_DESKTOP=%s\nDISPLAY=%s\nWAYLAND_DISPLAY=%s\n' \
  "${XDG_SESSION_TYPE:-unset}" "${XDG_CURRENT_DESKTOP:-unset}" \
  "${XDG_SESSION_DESKTOP:-unset}" "${DISPLAY:-unset}" "${WAYLAND_DISPLAY:-unset}"
if have systemctl; then
  echo 'systemd user-manager environment:'
  systemctl --user show-environment 2>/dev/null |
    grep -E '^(XDG_CURRENT_DESKTOP|XDG_SESSION_TYPE|WAYLAND_DISPLAY|DISPLAY|HYPRLAND_INSTANCE_SIGNATURE)=' || true
  echo 'Graphical/session/portal services:'
  for unit in graphical-session.target hyprland-session.target xdg-desktop-portal.service \
    xdg-desktop-portal-hyprland.service xdg-desktop-portal-gtk.service noctalia-shell.service \
    hyprland-workspace-recovery.service; do
    state="$(systemctl --user is-active "$unit" 2>/dev/null || true)"
    printf '  %-42s %s\n' "$unit" "${state:-unknown}"
  done
  echo 'Failed user units:'
  systemctl --user --failed --no-legend --no-pager 2>/dev/null || true
fi

section 'Display outputs'
if have hyprctl && have jq; then
  hyprctl monitors -j 2>/dev/null | jq -r '.[] | "\(.name): \(.width)x\(.height)@\(.refreshRate)Hz, scale=\(.scale), VRR=\(.vrr // "n/a"), \(.description // "")"' || true
  printf 'Headless outputs: '
  hyprctl monitors -j 2>/dev/null | jq '[.[] | select((.name // "") | startswith("HEADLESS"))] | length' || true
else
  echo 'hyprctl/jq unavailable; skipping output inventory'
fi

section 'XDG desktop and autostart files'
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
data_dirs="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
IFS=: read -r -a base_dirs <<< "$data_dirs"
roots=("$data_home/applications")
for root in "${base_dirs[@]}"; do
  [[ -n "$root" ]] && roots+=("$root/applications")
done
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
config_dirs="${XDG_CONFIG_DIRS:-/etc/xdg}"
IFS=: read -r -a config_bases <<< "$config_dirs"
autostart_roots=("$config_home/autostart")
for root in "${config_bases[@]}"; do
  [[ -n "$root" ]] && autostart_roots+=("$root/autostart")
done
session_roots=()
for root in "${base_dirs[@]}"; do
  [[ -n "$root" ]] && session_roots+=("$root/wayland-sessions" "$root/xsessions")
done
declare -A first_seen=()
count=0
shadowed=0
invalid=0
stale=0
scan_namespace() {
  local namespace="$1" root file rel id output key value
  shift
  local -a scan_roots=("$@")
  for root in "${scan_roots[@]}"; do
    [[ -d "$root" ]] || continue
    while IFS= read -r -d '' file; do
      ((count+=1))
      rel="${file#"$root"/}"
      id="${rel//\//-}"
      key="$namespace/$id"
      if [[ -v 'first_seen[$key]' ]]; then
        ((shadowed+=1))
        printf 'SHADOWED %-12s %s (winner: %s)\n' "$namespace" "$file" "${first_seen[$key]}"
      else
        first_seen["$key"]="$file"
      fi
      if have desktop-file-validate; then
        if ! output="$(desktop-file-validate "$file" 2>&1)"; then
          ((invalid+=1))
          printf 'INVALID  %-12s %s\n' "$namespace" "$file"
          printf '  %s\n' "$output"
        elif [[ -n "$output" ]]; then
          printf 'NOTICE   %-12s %s: %s\n' "$namespace" "$file" "$output"
        fi
      fi
      value="$(sed -n 's/^TryExec=//p' "$file" | head -n1 || true)"
      if [[ "$value" = /* && ! -e "$value" ]]; then
        ((stale+=1))
        printf 'STALE    %-12s missing TryExec=%s (%s)\n' "$namespace" "$value" "$file"
      fi
    done < <(find -L "$root" -type f -name '*.desktop' -print0 2>/dev/null || true)
  done
}
scan_namespace applications "${roots[@]}"
scan_namespace autostart "${autostart_roots[@]}"
scan_namespace sessions "${session_roots[@]}"
printf 'Scanned %d entries; %d shadowed IDs; %d invalid entries; %d stale TryExec paths.\n' \
  "$count" "$shadowed" "$invalid" "$stale"
echo 'SHADOWED indicates precedence, not automatically an error.'

section 'Portal configuration locations'
for root in "$config_home" "${config_bases[@]}" "$data_home" "${base_dirs[@]}"; do
  for file in "$root/xdg-desktop-portal/hyprland-portals.conf" \
              "$root/xdg-desktop-portal/portals.conf"; do
    [[ -e "$file" ]] && printf '  %s\n' "$file"
  done
done

section 'Useful follow-up commands'
printf '%s\n' \
  'journalctl --user -b -u xdg-desktop-portal -u xdg-desktop-portal-hyprland --no-pager -n 100' \
  'journalctl --user -b -u hyprland-workspace-recovery --no-pager -n 100' \
  'systemctl --user cat graphical-session.target hyprland-session.target'
