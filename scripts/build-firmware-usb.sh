#!/usr/bin/env bash
# Build the throwaway "FAT firmware" USB for ASUS BIOS FlashBack.
#
# Motherboard FlashBack demands a single-partition FAT32/16 stick with the BIOS
# image renamed to the board's expected filename. For the ASUS TUF GAMING
# B850-E WIFI that name is  A5653.CAP.
#
# Keep this stick SEPARATE from the Windows installer USB (the Kingston 16 GB is
# the designated throwaway).
#
# Usage:
#   lsblk -o NAME,SIZE,MODEL,TRAN,LABEL
#   sudo ./scripts/build-firmware-usb.sh --device /dev/sdX --bios-zip ~/win-kit-staging/firmware/TUF-...-B850-E.zip
#
# Options:
#   --device /dev/sdX   Whole-disk target (required, e.g. the Kingston)
#   --bios-zip PATH     ASUS BIOS .zip (auto-found in ~/win-kit-staging/firmware if omitted)
#   --cap-name NAME     Target .CAP filename (default: A5653.CAP for B850-E WIFI)
#   --label NAME        FAT label (default: FIRMWARE)
#   --yes               Skip the destructive-write confirmation

set -euo pipefail

DEVICE=""
BIOS_ZIP=""
CAP_NAME="A5653.CAP"
LABEL="FIRMWARE"
ASSUME_YES=0

log() { echo "[firmware-usb] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }
usage() { sed -n '2,24p' "$0"; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)   DEVICE="$2"; shift 2 ;;
    --bios-zip) BIOS_ZIP="$2"; shift 2 ;;
    --cap-name) CAP_NAME="$2"; shift 2 ;;
    --label)    LABEL="$2"; shift 2 ;;
    --yes)      ASSUME_YES=1; shift ;;
    -h|--help)  usage ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ -n "$DEVICE" ]] || die "--device is required (whole disk, e.g. /dev/sdb)"
[[ "$DEVICE" =~ ^/dev/[a-z]+[0-9]*$ ]] || die "--device must look like /dev/sdX (not a partition)"
[[ -b "$DEVICE" ]] || die "$DEVICE is not a block device"
[[ "$DEVICE" =~ [0-9]$ ]] && die "Use the whole disk ($DEVICE), not a partition"
[[ ${#LABEL} -le 11 ]] || die "FAT label '$LABEL' exceeds 11 characters"

if [[ -z "$BIOS_ZIP" ]]; then
  for c in "$HOME/win-kit-staging/firmware/"*.zip "$HOME/Downloads/"*[Bb]850*[Ee]*.zip; do
    [[ -f "$c" ]] && { BIOS_ZIP="$c"; break; }
  done
fi
[[ -f "$BIOS_ZIP" ]] || die "--bios-zip PATH required (no BIOS zip in ~/win-kit-staging/firmware)"

[[ "$(id -u)" -eq 0 ]] || die "Run as root: sudo $0 --device $DEVICE --bios-zip $BIOS_ZIP"
for t in sgdisk mkfs.vfat unzip partprobe; do
  command -v "$t" >/dev/null 2>&1 || die "missing required tool: $t"
done

log "Device:   $DEVICE ($(lsblk -d -n -o SIZE,MODEL,TRAN "$DEVICE" | tr -s ' '))"
log "BIOS zip: $BIOS_ZIP"
log "CAP name: $CAP_NAME"
lsblk -o NAME,SIZE,LABEL,FSTYPE,MOUNTPOINT "$DEVICE" || true
echo
log "This will ERASE all data on $DEVICE."
if [[ $ASSUME_YES -eq 0 ]]; then
  read -r -p "Type YES to continue: " confirm
  [[ "$confirm" == "YES" ]] || die "Aborted"
fi

MNT=""
TMP=""
cleanup() {
  [[ -n "$MNT" ]] && { umount "$MNT" 2>/dev/null || true; rmdir "$MNT" 2>/dev/null || true; }
  [[ -n "$TMP" && -d "$TMP" ]] && rm -rf "$TMP"
}
trap cleanup EXIT

log "Unmounting any partitions on $DEVICE..."
while read -r n; do
  [[ -n "$n" ]] || continue
  umount "/dev/$n" 2>/dev/null || true
  udisksctl unmount -b "/dev/$n" 2>/dev/null || true
done < <(lsblk -ln -o NAME "$DEVICE" | tail -n +2)

# FlashBack requires a single partition. Use a DOS/MBR table for max firmware
# compatibility on this throwaway stick.
log "Partitioning $DEVICE (single FAT32 partition)..."
sgdisk --zap-all "$DEVICE" >/dev/null
# Recreate as MBR with one primary FAT32 partition.
parted -s "$DEVICE" mklabel msdos
parted -s "$DEVICE" mkpart primary fat32 1MiB 100%
partprobe "$DEVICE" 2>/dev/null || true
udevadm settle || true

if [[ "$DEVICE" =~ (nvme|mmcblk|loop|nbd)[0-9]+$ ]]; then PART="${DEVICE}p1"; else PART="${DEVICE}1"; fi
[[ -b "$PART" ]] || die "could not resolve partition node for $DEVICE"

log "Formatting $PART as FAT32 ($LABEL)..."
mkfs.vfat -F32 -n "$LABEL" "$PART" >/dev/null

TMP=$(mktemp -d)
log "Extracting BIOS zip..."
unzip -o -q "$BIOS_ZIP" -d "$TMP"

CAP_SRC="$(find "$TMP" -iname '*.cap' -type f | head -1)"
[[ -n "$CAP_SRC" ]] || die "no .CAP file found inside $BIOS_ZIP"
log "Found BIOS image: $(basename "$CAP_SRC")"

MNT=$(mktemp -d)
mount "$PART" "$MNT"
cp "$CAP_SRC" "$MNT/$CAP_NAME"
sync
log "Wrote $MNT/$CAP_NAME"
ls -la "$MNT" >&2
umount "$MNT"; rmdir "$MNT"; MNT=""
sync

cat >&2 <<EOF
[firmware-usb] Done. FlashBack procedure:
  1. Power OFF. Plug this stick into the rear BIOS FlashBack USB port (labelled).
  2. Connect 24-pin ATX power; PSU on. You do NOT need to boot the system.
  3. Hold the BIOS FlashBack button ~3s until the LED blinks; release.
  4. Wait until the LED stops blinking and goes OUT (do not interrupt).
EOF
