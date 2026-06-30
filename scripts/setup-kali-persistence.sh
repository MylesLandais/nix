#!/usr/bin/env bash
# Create a Kali USB persistence partition on the lacie drive.
#
# Kali live needs an ext4 partition labeled "persistence" for writable
# sessions (saved WiFi, apt cache, files across reboots). Boot it via:
#   Lacie GRUB → Kali submenu → "Live system with USB persistence"
#
# This script only consumes **unallocated** space at the end of the disk.
# It does not shrink lacie_isos or touch live_nix / persistent_data.
# To free space, shrink the exFAT lacie_isos partition manually first.
#
# Usage:
#   sudo ./scripts/setup-kali-persistence.sh --device /dev/sda --size-gib 32
#   sudo ./scripts/setup-kali-persistence.sh --device /dev/sda --size-gib 32 --union
#
# See docs/cluster/kali-lacie-boot.md

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE=""
SIZE_GIB=""
USE_UNION=0

log() { echo "[kali-persistence] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }

usage() {
  sed -n '2,16p' "$0"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)    DEVICE="$2"; shift 2 ;;
    --size-gib)  SIZE_GIB="$2"; shift 2 ;;
    --union)     USE_UNION=1; shift ;;
    -h|--help)   usage ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ -n "$DEVICE" ]] || die "--device is required"
[[ "$DEVICE" =~ ^/dev/ ]] || die "--device must be a block device (e.g. /dev/sda)"
[[ -n "$SIZE_GIB" ]] || die "--size-gib is required"
[[ "$SIZE_GIB" =~ ^[0-9]+$ ]] || die "--size-gib must be an integer"
(( SIZE_GIB >= 4 )) || die "Minimum persistence size is 4 GiB"

if [[ ! -b "$DEVICE" ]]; then
  die "$DEVICE is not a block device"
fi

if [[ "$(id -u)" -ne 0 ]]; then
  die "Run as root: sudo $0 --device $DEVICE --size-gib $SIZE_GIB"
fi

log "Target: $DEVICE (${SIZE_GIB} GiB persistence partition)"
log "Current layout:"
lsblk -f "$DEVICE" || true
parted -s "$DEVICE" unit GiB print free || true

read -r -p "Type the device path again to confirm DESTRUCTIVE partition changes [$DEVICE]: " confirm
[[ "$confirm" == "$DEVICE" ]] || die "Aborted (confirmation mismatch)"

# Bytes of unallocated space at end of disk (parted free Space line).
free_bytes=$(parted -s "$DEVICE" unit B print free 2>/dev/null \
  | awk '/^ [0-9]+B.*Free Space/ { print $1 }' | sed 's/B$//' | tail -1)
[[ -n "${free_bytes:-}" && "$free_bytes" =~ ^[0-9]+$ ]] || die \
  "No unallocated space at end of $DEVICE. Shrink lacie_isos (exFAT) with parted/gparted, then re-run."

need_bytes=$(( SIZE_GIB * 1024 * 1024 * 1024 ))
(( free_bytes >= need_bytes )) || die \
  "Only $(( free_bytes / 1024 / 1024 / 1024 )) GiB free; requested ${SIZE_GIB} GiB."

if blkid -L persistence >/dev/null 2>&1; then
  die "Partition label 'persistence' already exists ($(blkid -L persistence)). Skip or remove it first."
fi

# Next free partition number
max_part=$(sgdisk -p "$DEVICE" 2>/dev/null | awk '/^ *[0-9]+ / { n=$1 } END { print n+0 }')
next_part=$(( max_part + 1 ))

log "Creating partition ${next_part} (${SIZE_GIB} GiB, label persistence)..."
sgdisk -n "${next_part}:0:-${SIZE_GIB}G" -t "${next_part}:8300" -c "${next_part}:persistence" "$DEVICE"
partprobe "$DEVICE" 2>/dev/null || true
udevadm settle || true
sleep 2

PERSIST_DEV="${DEVICE}${next_part}"
[[ -b "$PERSIST_DEV" ]] || PERSIST_DEV=$(readlink -f "/dev/disk/by-partlabel/persistence" 2>/dev/null || true)
[[ -b "$PERSIST_DEV" ]] || die "Could not find new persistence block device"

log "Formatting $PERSIST_DEV as ext4 (label persistence)..."
mkfs.ext4 -F -L persistence "$PERSIST_DEV"

if [[ $USE_UNION -eq 1 ]]; then
  log "Writing persistence.conf (union overlay — full RW root, more USB wear)..."
  mnt=$(mktemp -d)
  mount "$PERSIST_DEV" "$mnt"
  printf '%s\n' '/ union' > "$mnt/persistence.conf"
  sync
  umount "$mnt"
  rmdir "$mnt"
else
  log "Skipping persistence.conf (Kali defaults to overlay on home; add --union for full RW root)"
fi

log "Done."
lsblk -f "$PERSIST_DEV"
log "Boot path: F12 → LaCie → Kali submenu → Live system with USB persistence"
log "Verify: touch /root/persist-test && reboot → file should remain"
