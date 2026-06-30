#!/usr/bin/env bash
# Build a fully-FOSS GRUB multiboot USB: a self-built grub-mkstandalone EFI + a
# plain, editable grub.cfg. No agFM, no Ventoy, no vendor blobs.
#
# Layout (GPT):
#   p1  FAT32  ~1G   ESP  -> \EFI\BOOT\BOOTX64.EFI (grub) + \boot\grub\grub.cfg
#   p2  NTFS   rest  data -> EXTRACTED Win11 ISO at root + nixos-*.iso + autounattend.xml
#
# Windows-via-GRUB note: GRUB loopback of a Windows ISO does NOT work for Setup
# (Setup can't find boot.wim). We EXTRACT the Win11 ISO to the NTFS root and
# chainload its bootmgr — that works. NixOS uses GRUB loopback + findiso=.
#
# Runs with Secure Boot OFF (the EFI is unsigned). Re-enable SB after installing
# Windows (MS-signed bootmgr boots SB-on natively).
#
# Usage:
#   lsblk -o NAME,SIZE,MODEL,TRAN,LABEL
#   sudo ./scripts/setup-grub-multiboot-usb.sh --device /dev/sdX \
#        --win-iso ~/Downloads/Win11_24H2_English_x64.iso [--nixos-iso ~/Downloads/nixos.iso]
#
# Options:
#   --device /dev/sdX     Whole-disk target (required)
#   --win-iso PATH        Windows ISO (auto-find Win11_* in ~/Downloads if omitted)
#   --nixos-iso PATH      Optional NixOS ISO file (copied, loopback-booted)
#   --efi-label NAME      FAT32 label (default MBOOT_EFI; <=11 chars)
#   --payload-label NAME  NTFS label  (default PAYLOAD)
#   --yes                 Skip the destructive-write confirmation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DEVICE=""
WIN_ISO=""
NIXOS_ISO=""
EFI_LABEL="MBOOT_EFI"
PAYLOAD_LABEL="PAYLOAD"
ASSUME_YES=0

log() { echo "[grub-multiboot] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }
usage() { sed -n '2,33p' "$0"; exit 0; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)        DEVICE="$2"; shift 2 ;;
    --win-iso)       WIN_ISO="$2"; shift 2 ;;
    --nixos-iso)     NIXOS_ISO="$2"; shift 2 ;;
    --efi-label)     EFI_LABEL="$2"; shift 2 ;;
    --payload-label) PAYLOAD_LABEL="$2"; shift 2 ;;
    --yes)           ASSUME_YES=1; shift ;;
    -h|--help)       usage ;;
    *) die "Unknown argument: $1" ;;
  esac
done

# --- validation ---------------------------------------------------------------

[[ -n "$DEVICE" ]] || die "--device is required (whole disk, e.g. /dev/sdb)"
[[ "$DEVICE" =~ ^/dev/[a-z]+[0-9]*$ ]] || die "--device must look like /dev/sdX (not a partition)"
[[ -b "$DEVICE" ]] || die "$DEVICE is not a block device"
[[ "$DEVICE" =~ [0-9]$ ]] && die "Use the whole disk ($DEVICE), not a partition"
[[ ${#EFI_LABEL} -le 11 ]] || die "FAT label '$EFI_LABEL' exceeds 11 characters"
[[ "$(id -u)" -eq 0 ]] || die "Run as root: sudo $0 --device $DEVICE"

if [[ -z "$WIN_ISO" ]]; then
  for c in "$HOME/Downloads/Win11_"*.iso "$HOME/Downloads/Win10_"*.iso "$HOME/Downloads/"*[Ww]indows*.iso; do
    [[ -f "$c" ]] && { WIN_ISO="$c"; break; }
  done
fi
[[ -f "$WIN_ISO" ]] || die "--win-iso PATH required (no Windows ISO found in ~/Downloads)"
[[ -z "$NIXOS_ISO" || -f "$NIXOS_ISO" ]] || die "--nixos-iso not found: $NIXOS_ISO"

UNATTEND="$REPO_ROOT/windows-kit/autounattend.xml"

for t in sgdisk mkfs.vfat mkfs.ntfs rsync partprobe blkid; do
  command -v "$t" >/dev/null 2>&1 || die "missing required tool: $t"
done

# Resolve grub-mkstandalone (PATH, else build grub2_efi via nix).
GRUB_PKG=""
if command -v grub-mkstandalone >/dev/null 2>&1; then
  GRUB_MK=$(command -v grub-mkstandalone)
else
  log "grub-mkstandalone not on PATH; resolving grub2_efi via nix..."
  GRUB_PKG=$(nix build --no-link --print-out-paths nixpkgs#grub2_efi 2>/dev/null | head -1) \
    || die "grub-mkstandalone unavailable; add grub2_efi to packages or run nix-switch"
  GRUB_MK="$GRUB_PKG/bin/grub-mkstandalone"
  [[ -x "$GRUB_MK" ]] || die "grub-mkstandalone not in $GRUB_PKG"
fi

iso_bytes=$(stat -c %s "$WIN_ISO")
disk_bytes=$(lsblk -b -d -n -o SIZE "$DEVICE")
(( disk_bytes > iso_bytes + 2*1024*1024*1024 )) || die "disk too small for $WIN_ISO + headroom"

log "Device:    $DEVICE ($(lsblk -d -n -o SIZE,MODEL,TRAN "$DEVICE" | tr -s ' '))"
log "Win ISO:   $WIN_ISO ($(numfmt --to=iec "$iso_bytes"))"
[[ -n "$NIXOS_ISO" ]] && log "NixOS ISO: $NIXOS_ISO"
log "GRUB:      $GRUB_MK"
lsblk -o NAME,SIZE,LABEL,FSTYPE,MOUNTPOINT "$DEVICE" || true
echo
log "This will ERASE all data on $DEVICE."
if [[ $ASSUME_YES -eq 0 ]]; then
  read -r -p "Type YES to continue: " confirm
  [[ "$confirm" == "YES" ]] || die "Aborted"
fi

# --- cleanup ------------------------------------------------------------------

ESP_MNT=""; PAY_MNT=""; WISO_MNT=""; NISO_MNT=""; EARLY_CFG=""
cleanup() {
  for m in "$WISO_MNT" "$NISO_MNT" "$PAY_MNT" "$ESP_MNT"; do
    [[ -n "$m" ]] && { umount "$m" 2>/dev/null || true; rmdir "$m" 2>/dev/null || true; }
  done
  [[ -n "$EARLY_CFG" ]] && rm -f "$EARLY_CFG"
}
trap cleanup EXIT

log "Unmounting any partitions on $DEVICE..."
while read -r n; do
  [[ -n "$n" ]] || continue
  umount "/dev/$n" 2>/dev/null || true
  udisksctl unmount -b "/dev/$n" 2>/dev/null || true
done < <(lsblk -ln -o NAME "$DEVICE" | tail -n +2)

# --- partition ----------------------------------------------------------------

log "Partitioning $DEVICE (GPT: FAT32 ESP + NTFS payload)..."
sgdisk --zap-all "$DEVICE" >/dev/null
sgdisk --new=1:0:+1G  --typecode=1:ef00 --change-name=1:"$EFI_LABEL" \
       --new=2:0:0    --typecode=2:0700 --change-name=2:"$PAYLOAD_LABEL" "$DEVICE" >/dev/null
partprobe "$DEVICE" 2>/dev/null || true
udevadm settle || true

if [[ "$DEVICE" =~ (nvme|mmcblk|loop|nbd)[0-9]+$ ]]; then P1="${DEVICE}p1"; P2="${DEVICE}p2"; else P1="${DEVICE}1"; P2="${DEVICE}2"; fi
[[ -b "$P1" && -b "$P2" ]] || die "could not resolve partition nodes ($P1 / $P2)"

log "Formatting $P1 FAT32 ($EFI_LABEL) and $P2 NTFS ($PAYLOAD_LABEL)..."
mkfs.vfat -F32 -n "$EFI_LABEL" "$P1" >/dev/null
mkfs.ntfs -Q -L "$PAYLOAD_LABEL" "$P2" >/dev/null

ESP_MNT=$(mktemp -d); PAY_MNT=$(mktemp -d)
mount "$P1" "$ESP_MNT"
mount "$P2" "$PAY_MNT"

# --- build GRUB (monolithic, modules baked in) --------------------------------

log "Building grub-mkstandalone EFI..."
mkdir -p "$ESP_MNT/EFI/BOOT" "$ESP_MNT/boot/grub"
EARLY_CFG=$(mktemp)
cat > "$EARLY_CFG" <<EARLY
search --no-floppy --label $EFI_LABEL --set=root
set prefix=(\$root)/boot/grub
configfile (\$root)/boot/grub/grub.cfg
EARLY

"$GRUB_MK" \
  --format=x86_64-efi \
  ${GRUB_PKG:+--directory="$GRUB_PKG/lib/grub/x86_64-efi"} \
  --modules="part_gpt part_msdos fat ntfs ntfscomp exfat iso9660 udf search search_label search_fs_uuid chain configfile normal linux loopback echo test all_video ls cat halt reboot efifwsetup" \
  --output="$ESP_MNT/EFI/BOOT/BOOTX64.EFI" \
  "boot/grub/grub.cfg=$EARLY_CFG"

# --- extract Windows ISO to NTFS root + autounattend --------------------------

log "Extracting Windows ISO to NTFS root (this takes a while)..."
WISO_MNT=$(mktemp -d)
mount -o loop,ro "$WIN_ISO" "$WISO_MNT"
rsync -a --info=progress2 "$WISO_MNT"/ "$PAY_MNT"/
umount "$WISO_MNT"; rmdir "$WISO_MNT"; WISO_MNT=""

if [[ -f "$UNATTEND" ]]; then
  log "Placing autounattend.xml at payload root..."
  cp "$UNATTEND" "$PAY_MNT/autounattend.xml"
else
  log "note: $UNATTEND not found — Windows setup will be interactive"
fi

# --- NixOS entry (optional) ---------------------------------------------------

NIXOS_MENU=""
if [[ -n "$NIXOS_ISO" ]]; then
  nixos_base="$(basename "$NIXOS_ISO")"
  log "Copying NixOS ISO ($nixos_base) to payload root..."
  rsync -a --info=progress2 "$NIXOS_ISO" "$PAY_MNT/$nixos_base"

  # Pull the kernel cmdline + initrd path from the ISO's own grub.cfg so the
  # loopback entry isn't hardcoded (mirrors test-usb-qemu.sh's init= extraction).
  NISO_MNT=$(mktemp -d)
  lin=""; ini=""
  if mount -o loop,ro "$NIXOS_ISO" "$NISO_MNT" 2>/dev/null; then
    for cfg in "$NISO_MNT/boot/grub/grub.cfg" "$NISO_MNT/EFI/BOOT/grub.cfg" "$NISO_MNT/boot/grub/loopback.cfg"; do
      [[ -f "$cfg" ]] || continue
      lin=$(grep -m1 -oE 'linux[[:space:]]+/?[^[:space:]]*bzImage[^\n]*' "$cfg" | sed -E 's#^linux[[:space:]]+/?#/#' || true)
      ini=$(grep -m1 -oE 'initrd[[:space:]]+/?[^[:space:]]+' "$cfg" | sed -E 's#^initrd[[:space:]]+/?#/#' || true)
      [[ -n "$lin" && -n "$ini" ]] && break
    done
    umount "$NISO_MNT" 2>/dev/null || true
  fi
  rmdir "$NISO_MNT" 2>/dev/null || true; NISO_MNT=""

  if [[ -n "$lin" && -n "$ini" ]]; then
    # $lin is like "/boot/bzImage init=/nix/store/.../init ...". Prefix (loop), add findiso.
    kparams="${lin#*bzImage}"
    NIXOS_MENU=$(cat <<EOF

menuentry "Install NixOS ($nixos_base)" {
  insmod ntfs
  insmod loopback
  insmod iso9660
  search --no-floppy --label $PAYLOAD_LABEL --set=root
  loopback loop (\$root)/$nixos_base
  linux  (loop)/boot/bzImage${kparams} findiso=/$nixos_base
  initrd (loop)${ini}
}
EOF
)
  else
    log "WARNING: couldn't parse NixOS ISO grub.cfg — emitting a commented placeholder entry"
    NIXOS_MENU=$(cat <<EOF

# Could not auto-detect kernel params from $nixos_base.
# Mount it and copy the 'linux'/'initrd' lines from boot/grub/grub.cfg, add findiso=/$nixos_base.
#menuentry "Install NixOS ($nixos_base)" {
#  search --no-floppy --label $PAYLOAD_LABEL --set=root
#  loopback loop (\$root)/$nixos_base
#  linux  (loop)/boot/bzImage init=/nix/store/.../init findiso=/$nixos_base
#  initrd (loop)/boot/initrd
#}
EOF
)
  fi
fi

# --- write the editable grub.cfg ----------------------------------------------

log "Writing /boot/grub/grub.cfg..."
cat > "$ESP_MNT/boot/grub/grub.cfg" <<EOF
# FOSS GRUB multiboot — editable. Rebuild not needed after edits.
set timeout=15
set default=0

search --no-floppy --label $PAYLOAD_LABEL --set=payload

menuentry "Install Windows 11 (chainload bootmgr)" {
  insmod part_gpt
  insmod ntfs
  insmod chain
  set root=\$payload
  chainloader (\$payload)/efi/boot/bootx64.efi
}
${NIXOS_MENU}
menuentry "Reboot" { reboot }
menuentry "Shutdown" { halt }
menuentry "Firmware setup (UEFI)" { fwsetup }
EOF

sync

# --- verify -------------------------------------------------------------------

log "Verifying..."
ok=1
[[ -f "$ESP_MNT/EFI/BOOT/BOOTX64.EFI" ]] || { log "WARNING: BOOTX64.EFI missing"; ok=0; }
[[ -f "$ESP_MNT/boot/grub/grub.cfg" ]]   || { log "WARNING: grub.cfg missing"; ok=0; }
[[ -f "$PAY_MNT/sources/install.wim" ]]  || { log "WARNING: payload sources/install.wim missing"; ok=0; }
[[ -f "$PAY_MNT/efi/boot/bootx64.efi" ]] || { log "WARNING: payload efi/boot/bootx64.efi missing (Windows chainload target)"; ok=0; }

umount "$PAY_MNT"; rmdir "$PAY_MNT"; PAY_MNT=""
umount "$ESP_MNT"; rmdir "$ESP_MNT"; ESP_MNT=""
sync

log "Partition layout:"
lsblk -o NAME,SIZE,LABEL,FSTYPE,PARTTYPE "$DEVICE" || true

if [[ $ok -eq 1 ]]; then
  log "Done. FOSS GRUB multiboot USB ready on $DEVICE."
else
  log "Done WITH WARNINGS — review messages above."
fi
log "Boot: F12 -> UEFI: <USB>, Secure Boot OFF. Re-enable Secure Boot after Windows installs."
log "Validate in a VM: sudo ./scripts/test-windows-qemu.sh --device $DEVICE --no-secureboot --check-media"
