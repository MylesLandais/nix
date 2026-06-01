#!/usr/bin/env bash
# Stage a built installer ISO onto lacie_isos and refresh GRUB entries.
#
# Usage:
#   sudo ./scripts/stage-installer-iso.sh
#   sudo ./scripts/stage-installer-iso.sh /tmp/installer-iso/iso/nixos-*.iso
#   sudo ./scripts/stage-installer-iso.sh --device /dev/sda /path/to.iso

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="/dev/sda"
ISO_GLOB="/tmp/installer-iso/iso/*.iso"
TARGET_NAME="home-office-installer.iso"

log() { echo "[stage-iso] $*" >&2; }
die() { echo "[stage-iso] ERROR: $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "Run with sudo"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) DEVICE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,8p' "$0"
      exit 0
      ;;
    --) shift; break ;;
    *) break ;;
  esac
done

ISO_SRC="${1:-}"
if [[ -z "$ISO_SRC" ]]; then
  shopt -s nullglob
  _matches=( $ISO_GLOB )
  shopt -u nullglob
  ((${#_matches[@]})) || die "No ISO at $ISO_GLOB — pass path as argument"
  ISO_SRC="${_matches[0]}"
fi
[[ -f "$ISO_SRC" ]] || die "ISO not found: $ISO_SRC"

ISOS_PART="${DEVICE}2"
MNT=$(mktemp -d)

log "source:  $ISO_SRC ($(stat -c %s "$ISO_SRC") bytes)"
log "target:  $ISOS_PART:$TARGET_NAME"
log "refresh: $REPO_ROOT/scripts/setup-nix-usb.sh --device $DEVICE --grub-only"

mount -t exfat "$ISOS_PART" "$MNT"
trap 'umount "$MNT" 2>/dev/null; rmdir "$MNT" 2>/dev/null || true' EXIT

cp -v "$ISO_SRC" "$MNT/${TARGET_NAME}.new"
sync
mv -v "$MNT/${TARGET_NAME}.new" "$MNT/$TARGET_NAME"
sync

umount "$MNT"
rmdir "$MNT"
trap - EXIT

"$REPO_ROOT/scripts/setup-nix-usb.sh" --device "$DEVICE" --grub-only

log "done — run Tier 1–3 via test-usb-qemu.sh"
