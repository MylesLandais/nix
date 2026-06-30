#!/usr/bin/env bash
# Copy the Kali live ISO from lacie_isos (exFAT) onto live_nix (ext4) so the
# graphical installer can find installation media. The d-i initrd often cannot
# read ISOs on exFAT via loopback; ext4 + dedicated GRUB entry is reliable.
#
# Usage:
#   sudo ./scripts/stage-kali-for-install.sh
#   sudo ./scripts/stage-kali-for-install.sh --iso /run/media/warby/lacie_isos/kali-linux-2026.1-live-everything-amd64.iso
#
# Then refresh GRUB:
#   nix-shell -p grub2_efi --run 'sudo ./scripts/setup-nix-usb.sh --device /dev/sdb --grub-only'

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ISO_SRC=""
DEST_NAME="kali-installer-loopback.iso"
LIVE_LABEL="live_nix"
ISOS_LABEL="lacie_isos"

log() { echo "[stage-kali-install] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --iso) ISO_SRC="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ "$(id -u)" -eq 0 ]] || die "Run as root"

if [[ -z "$ISO_SRC" ]]; then
  isos_mnt=$(findmnt -n -o TARGET -L "$ISOS_LABEL" 2>/dev/null || true)
  [[ -n "$isos_mnt" ]] || die "Mount $ISOS_LABEL or pass --iso PATH"
  matches=("$isos_mnt"/kali-linux-*-live-*.iso)
  [[ -f "${matches[0]}" ]] || die "No kali-linux-*-live-*.iso under $isos_mnt"
  ISO_SRC="${matches[0]}"
fi

[[ -f "$ISO_SRC" ]] || die "ISO not found: $ISO_SRC"

live_mnt=$(findmnt -n -o TARGET -L "$LIVE_LABEL" 2>/dev/null || true)
if [[ -z "$live_mnt" ]]; then
  live_dev=$(blkid -L "$LIVE_LABEL" 2>/dev/null || true)
  [[ -n "$live_dev" ]] || die "No partition labeled $LIVE_LABEL"
  live_mnt=$(mktemp -d)
  mount "$live_dev" "$live_mnt"
  umount_live=1
else
  umount_live=0
fi

dest="${live_mnt}/${DEST_NAME}"
src_size=$(stat -c %s "$ISO_SRC")
free_kb=$(df -k "$live_mnt" | awk 'NR==2 { print $4 }')
need_kb=$(( src_size / 1024 + 1048576 ))
(( free_kb > need_kb )) || die "Need ~$(( need_kb / 1024 / 1024 )) GiB free on $LIVE_LABEL; have $(( free_kb / 1024 / 1024 )) GiB"

log "Source: $ISO_SRC ($(numfmt --to=iec "$src_size" 2>/dev/null || echo "${src_size} B"))"
log "Dest:   $dest"

if [[ -f "$dest" ]]; then
  dest_size=$(stat -c %s "$dest")
  if [[ "$dest_size" -eq "$src_size" ]]; then
    log "Already staged (same size). Skipping copy."
  else
    log "Replacing existing staged ISO..."
    rm -f "$dest"
  fi
fi

if [[ ! -f "$dest" ]]; then
  log "Copying (this may take several minutes)..."
  cp -v --reflink=auto "$ISO_SRC" "${dest}.partial"
  sync
  mv "${dest}.partial" "$dest"
  sync
fi

[[ $umount_live -eq 1 ]] && umount "$live_mnt" && rmdir "$live_mnt"

disk=$(lsblk -no PKNAME "$(blkid -L "$LIVE_LABEL")" 2>/dev/null | head -1)
log "Done. Refresh GRUB on /dev/${disk:-sdb}:"
log "  nix-shell -p grub2_efi --run 'sudo $REPO_ROOT/scripts/setup-nix-usb.sh --device /dev/${disk:-sdb} --grub-only'"
log "Boot: **Kali Graphical Install (ext4 on live_nix)** — not the exFAT submenu installer."
