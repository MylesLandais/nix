#!/usr/bin/env bash
# Write a Kali ISO directly to a USB stick (dd / isohybrid). No lacie GRUB layer.
#
# Use the **installer** ISO for bare-metal install; use **live** ISO for live-only USB.
#
# Usage:
#   lsblk -o NAME,SIZE,MODEL,TRAN,LABEL
#   sudo ./scripts/write-kali-usb.sh --device /dev/sdX --iso ~/Downloads/kali-linux-2026-W19-installer-amd64.iso
#
# The block device must be the whole disk (e.g. /dev/sdb), not a partition (/dev/sdb1).

set -euo pipefail

DEVICE=""
ISO=""
ASSUME_YES=0

log() { echo "[write-kali-usb] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }

usage() {
  sed -n '2,12p' "$0"
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) DEVICE="$2"; shift 2 ;;
    --iso)    ISO="$2"; shift 2 ;;
    --yes)    ASSUME_YES=1; shift ;;
    -h|--help) usage ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ -n "$DEVICE" ]] || die "--device is required (whole disk, e.g. /dev/sdb)"
[[ "$DEVICE" =~ ^/dev/[a-z]+[0-9]*$ ]] || die "--device must look like /dev/sdX (not a partition)"
[[ -b "$DEVICE" ]] || die "$DEVICE is not a block device"
[[ "$DEVICE" =~ [0-9]$ ]] && die "Use the whole disk ($DEVICE), not a partition"

if [[ -z "$ISO" ]]; then
  for candidate in \
    "$HOME/Downloads/kali-linux-"*"-installer-"*.iso \
    "$HOME/Downloads/kali-linux-"*"-live-"*.iso; do
    [[ -f "$candidate" ]] && { ISO="$candidate"; break; }
  done
fi
[[ -f "$ISO" ]] || die "--iso PATH required (no Kali ISO found in ~/Downloads)"

[[ "$(id -u)" -eq 0 ]] || die "Run as root: sudo $0 --device $DEVICE --iso $ISO"

iso_bytes=$(stat -c %s "$ISO")
disk_bytes=$(lsblk -b -d -n -o SIZE "$DEVICE")
(( disk_bytes > iso_bytes )) || die "ISO ($(numfmt --to=iec "$iso_bytes" 2>/dev/null || echo "$iso_bytes")) larger than $DEVICE"

log "ISO:   $ISO"
log "Disk:  $DEVICE ($(lsblk -d -n -o SIZE,MODEL,TRAN "$DEVICE" | tr -s ' '))"
lsblk -o NAME,SIZE,LABEL,FSTYPE,MOUNTPOINT "$DEVICE" || true
echo
log "This will ERASE all data on $DEVICE."
if [[ $ASSUME_YES -eq 0 ]]; then
  read -r -p "Type YES to continue: " confirm
  [[ "$confirm" == "YES" ]] || die "Aborted"
fi

log "Unmounting partitions on $DEVICE..."
while read -r part; do
  [[ -n "$part" ]] || continue
  umount "$part" 2>/dev/null || true
  udisksctl unmount -b "$part" 2>/dev/null || true
done < <(lsblk -ln -o NAME "$DEVICE" | tail -n +2 | while read -r n; do echo "/dev/$n"; done)

log "Writing ISO (several minutes)..."
dd if="$ISO" of="$DEVICE" bs=4M status=progress conv=fsync

sync
partprobe "$DEVICE" 2>/dev/null || true
udevadm settle || true

log "Partition layout after write:"
lsblk -o NAME,SIZE,LABEL,FSTYPE,PARTTYPE,PARTFLAGS "$DEVICE" || true

efi_part=""
while read -r part fstype; do
  [[ "$fstype" == "vfat" ]] && efi_part="$part" && break
done < <(lsblk -ln -o NAME,FSTYPE "$DEVICE" | tail -n +2 | while read -r n t; do echo "/dev/$n $t"; done)

if [[ -n "$efi_part" ]]; then
  mnt=$(mktemp -d)
  if mount "$efi_part" "$mnt" 2>/dev/null; then
    if [[ -f "$mnt/EFI/BOOT/BOOTX64.EFI" || -f "$mnt/EFI/BOOT/grubx64.efi" ]]; then
      log "UEFI boot files present on $efi_part (EFI/BOOT/)."
    else
      log "WARNING: $efi_part mounted but EFI/BOOT/BOOTX64.EFI not found — UEFI boot may fail."
    fi
    umount "$mnt" 2>/dev/null || true
  fi
  rmdir "$mnt" 2>/dev/null || true
else
  log "WARNING: no vfat partition seen — isohybrid EFI slice missing; UEFI boot unlikely."
fi

log "Done. Secure Boot OFF on target. Legacy boot has worked on cluster hardware;"
log "UEFI: use F12 entry prefixed with UEFI: (not the legacy USB row). See docs/cluster/lacie-multiboot-kali-notes.md"
log "Installer ISO: pick Graphical install at the Kali GRUB menu."
lsblk -f "$DEVICE" || true
