#!/usr/bin/env bash
# Build a UEFI-bootable Windows installer USB (FAT32 + wimlib WIM split).
#
# Why FAT32 (not NTFS): every UEFI firmware boots FAT32 natively, so we avoid the
# UEFI:NTFS shim driver that has been flaky on our hardware. Modern Win11
# install.wim is >4 GiB, so we split it into install.swm chunks that fit FAT32's
# 4 GiB file cap — Windows setup reads .swm split files natively.
#
# Keeps TPM 2.0 + Secure Boot expectations intact (anti-cheat needs them); the
# bundled autounattend.xml only removes the Microsoft-account/OOBE online
# requirement, it does NOT bypass hardware checks.
#
# Usage:
#   lsblk -o NAME,SIZE,MODEL,TRAN,LABEL
#   sudo ./scripts/write-windows-usb.sh --device /dev/sdX --iso ~/Downloads/Win11_24H2_English_x64.iso
#
# The block device must be the whole disk (e.g. /dev/sdb), not a partition (/dev/sdb1).
#
# Options:
#   --device /dev/sdX   Whole-disk target (required)
#   --iso PATH          Windows ISO (auto-found in ~/Downloads / ~/win-kit-staging if omitted)
#   --unattend PATH     autounattend.xml to place at USB root (default: windows-kit/autounattend.xml)
#   --payload DIR       Extra files copied to USB root (quick_fix.ps1, Installers/, Drivers/)
#   --label NAME        FAT32 volume label (default: WIN_INSTALL; max 11 chars, uppercase)
#   --no-unattend       Do not copy any autounattend.xml (fully interactive setup)
#   --yes               Skip the destructive-write confirmation prompt

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DEVICE=""
ISO=""
UNATTEND="$REPO_ROOT/windows-kit/autounattend.xml"
PAYLOAD=""
LABEL="WIN_INSTALL"
COPY_UNATTEND=1
ASSUME_YES=0

log() { echo "[write-windows-usb] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }

usage() { sed -n '2,32p' "$0"; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)       DEVICE="$2"; shift 2 ;;
    --iso)          ISO="$2"; shift 2 ;;
    --unattend)     UNATTEND="$2"; shift 2 ;;
    --payload)      PAYLOAD="$2"; shift 2 ;;
    --label)        LABEL="$2"; shift 2 ;;
    --no-unattend)  COPY_UNATTEND=0; shift ;;
    --yes)          ASSUME_YES=1; shift ;;
    -h|--help)      usage ;;
    *) die "Unknown argument: $1" ;;
  esac
done

# --- validation ---------------------------------------------------------------

[[ -n "$DEVICE" ]] || die "--device is required (whole disk, e.g. /dev/sdb)"
[[ "$DEVICE" =~ ^/dev/[a-z]+[0-9]*$ ]] || die "--device must look like /dev/sdX (not a partition)"
[[ -b "$DEVICE" ]] || die "$DEVICE is not a block device"
[[ "$DEVICE" =~ [0-9]$ ]] && die "Use the whole disk ($DEVICE), not a partition"

if [[ -z "$ISO" ]]; then
  for candidate in \
    "$HOME/win-kit-staging/"*.iso \
    "$HOME/Downloads/Win11_"*.iso \
    "$HOME/Downloads/Win10_"*.iso \
    "$HOME/Downloads/"*[Ww]indows*.iso; do
    [[ -f "$candidate" ]] && { ISO="$candidate"; break; }
  done
fi
[[ -f "$ISO" ]] || die "--iso PATH required (no Windows ISO found in ~/win-kit-staging or ~/Downloads)"

[[ ${#LABEL} -le 11 ]] || die "FAT32 label '$LABEL' exceeds 11 characters"

[[ "$(id -u)" -eq 0 ]] || die "Run as root: sudo $0 --device $DEVICE --iso $ISO"

for tool in sgdisk mkfs.vfat wimlib-imagex rsync partprobe blkid; do
  command -v "$tool" >/dev/null 2>&1 || die "missing required tool: $tool"
done

if [[ $COPY_UNATTEND -eq 1 ]]; then
  [[ -f "$UNATTEND" ]] || die "autounattend not found: $UNATTEND (use --no-unattend to skip)"
fi
[[ -z "$PAYLOAD" || -d "$PAYLOAD" ]] || die "--payload dir not found: $PAYLOAD"

iso_bytes=$(stat -c %s "$ISO")
disk_bytes=$(lsblk -b -d -n -o SIZE "$DEVICE")
# Windows install media needs the full ISO contents; require comfortable headroom.
(( disk_bytes > iso_bytes )) || die "ISO ($(numfmt --to=iec "$iso_bytes")) larger than $DEVICE"

log "ISO:    $ISO ($(numfmt --to=iec "$iso_bytes"))"
log "Disk:   $DEVICE ($(lsblk -d -n -o SIZE,MODEL,TRAN "$DEVICE" | tr -s ' '))"
[[ $COPY_UNATTEND -eq 1 ]] && log "Unattend: $UNATTEND"
[[ -n "$PAYLOAD" ]] && log "Payload:  $PAYLOAD"
lsblk -o NAME,SIZE,LABEL,FSTYPE,MOUNTPOINT "$DEVICE" || true
echo
log "This will ERASE all data on $DEVICE."
if [[ $ASSUME_YES -eq 0 ]]; then
  read -r -p "Type YES to continue: " confirm
  [[ "$confirm" == "YES" ]] || die "Aborted"
fi

# --- cleanup / mounts ---------------------------------------------------------

ISO_MNT=""
USB_MNT=""
TMP_WIM=""
cleanup() {
  [[ -n "$USB_MNT" ]] && { umount "$USB_MNT" 2>/dev/null || true; rmdir "$USB_MNT" 2>/dev/null || true; }
  [[ -n "$ISO_MNT" ]] && { umount "$ISO_MNT" 2>/dev/null || true; rmdir "$ISO_MNT" 2>/dev/null || true; }
  [[ -n "$TMP_WIM" ]] && rm -f "$TMP_WIM" 2>/dev/null || true
}
trap cleanup EXIT

log "Unmounting any partitions on $DEVICE..."
while read -r n; do
  [[ -n "$n" ]] || continue
  umount "/dev/$n" 2>/dev/null || true
  udisksctl unmount -b "/dev/$n" 2>/dev/null || true
done < <(lsblk -ln -o NAME "$DEVICE" | tail -n +2)

# --- partition: single GPT FAT32 ESP -----------------------------------------

log "Partitioning $DEVICE (GPT, single FAT32 ESP)..."
sgdisk --zap-all "$DEVICE" >/dev/null
sgdisk --new=1:0:0 --typecode=1:ef00 --change-name=1:"$LABEL" "$DEVICE" >/dev/null
partprobe "$DEVICE" 2>/dev/null || true
udevadm settle || true

# Resolve partition node (nvme/mmc style vs sdX).
if [[ "$DEVICE" =~ (nvme|mmcblk|loop|nbd)[0-9]+$ ]]; then
  PART="${DEVICE}p1"
else
  PART="${DEVICE}1"
fi
[[ -b "$PART" ]] || PART="$(lsblk -ln -o PATH "$DEVICE" | tail -n +2 | head -1)"
[[ -b "$PART" ]] || die "could not resolve partition node for $DEVICE"

log "Formatting $PART as FAT32 ($LABEL)..."
mkfs.vfat -F32 -n "$LABEL" "$PART" >/dev/null

# --- copy ISO contents (sans install.wim) + split WIM ------------------------

ISO_MNT=$(mktemp -d)
USB_MNT=$(mktemp -d)
mount -o loop,ro "$ISO" "$ISO_MNT"
mount "$PART" "$USB_MNT"

[[ -f "$ISO_MNT/sources/install.wim" ]] || die "ISO has no sources/install.wim — not a Windows install ISO?"

log "Copying boot + setup files (excluding install.wim)..."
# FAT32 has no concept of ownership/group/unix perms, so -a's chown/chmod calls
# fail and make rsync exit 23, which set -e would treat as fatal. Copy contents
# recursively with timestamps only (-rt) and skip owner/group/perm preservation.
rsync -rt --info=progress2 --no-perms --no-owner --no-group \
  --exclude='sources/install.wim' "$ISO_MNT"/ "$USB_MNT"/

log "Splitting install.wim into <4 GiB install.swm chunks (this takes a while)..."
# Try a direct split first. Win11 24H2 ships install.wim with "solid" (LZMS)
# resources, which wimlib cannot split directly (exits 68). If that happens,
# export to a non-solid LZX temp WIM (on the ISO's filesystem, which has room)
# and split that instead. cleanup() removes the temp file.
if ! wimlib-imagex split "$ISO_MNT/sources/install.wim" "$USB_MNT/sources/install.swm" 3800; then
  log "Direct split failed (solid-compressed WIM); exporting to non-solid LZX first..."
  TMP_WIM="$(dirname "$ISO")/.install-nonsolid.$$.wim"
  rm -f "$USB_MNT"/sources/install*.swm 2>/dev/null || true
  wimlib-imagex export "$ISO_MNT/sources/install.wim" all "$TMP_WIM" --compress=LZX
  wimlib-imagex split "$TMP_WIM" "$USB_MNT/sources/install.swm" 3800
  rm -f "$TMP_WIM"; TMP_WIM=""
fi

# --- answer file + payload ----------------------------------------------------

if [[ $COPY_UNATTEND -eq 1 ]]; then
  log "Placing autounattend.xml at USB root..."
  cp "$UNATTEND" "$USB_MNT/autounattend.xml"
fi

if [[ -n "$PAYLOAD" ]]; then
  log "Copying payload from $PAYLOAD ..."
  rsync -a --info=progress2 "$PAYLOAD"/ "$USB_MNT"/
fi

sync

# --- verify -------------------------------------------------------------------

log "Verifying boot artifacts..."
boot_ok=1
[[ -f "$USB_MNT/efi/boot/bootx64.efi" || -f "$USB_MNT/EFI/BOOT/BOOTX64.EFI" ]] \
  || { log "WARNING: efi/boot/bootx64.efi not found — UEFI boot may fail"; boot_ok=0; }
[[ -f "$USB_MNT/sources/install.swm" ]] \
  || { log "WARNING: sources/install.swm missing — WIM split failed"; boot_ok=0; }
[[ -f "$USB_MNT/bootmgr" ]] || log "note: bootmgr not present (UEFI-only stick — fine)"

umount "$USB_MNT"; rmdir "$USB_MNT"; USB_MNT=""
umount "$ISO_MNT"; rmdir "$ISO_MNT"; ISO_MNT=""
sync

log "Partition layout:"
lsblk -o NAME,SIZE,LABEL,FSTYPE,PARTTYPE "$DEVICE" || true

if [[ $boot_ok -eq 1 ]]; then
  log "Done. UEFI-bootable Windows installer ready on $DEVICE."
else
  log "Done WITH WARNINGS — re-check the messages above before trusting this stick."
fi
log "Boot target: F12 -> UEFI: <USB>. Keep Secure Boot ON + TPM 2.0 ON for anti-cheat."
log "Validate first in a VM: nix run .#test-windows-qemu -- --iso \"$ISO\""
