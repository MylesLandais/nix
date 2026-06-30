#!/usr/bin/env bash
# Best-effort stage of the Windows driver pack for Jerad's build.
#
# Vendor CDNs (ASUS/AMD) hide downloads behind JS + Cloudflare, so this is NOT a
# reliable auto-downloader. It:
#   1. prints the exact vendor pages/URLs to grab manually,
#   2. extracts whatever installer .exe/.zip you drop into the staging dir into
#      flat .inf/.cat/.sys trees for offline injection,
#   3. assembles an optional $WinpeDriver$ tree (NIC/audio) for first-boot network.
#
# Usage:
#   ./scripts/fetch-driver-pack.sh                 # print manifest + URLs, then extract what's present
#   ./scripts/fetch-driver-pack.sh --staging DIR   # default: ~/win-kit-staging
#   ./scripts/fetch-driver-pack.sh --winpe         # also build $WinpeDriver$ from net/ + audio/

set -euo pipefail

STAGING="${STAGING:-$HOME/win-kit-staging}"
MAKE_WINPE=0

log() { echo "[driver-pack] $*" >&2; }
die() { log "ERROR: $*"; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staging) STAGING="$2"; shift 2 ;;
    --winpe)   MAKE_WINPE=1; shift ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) die "Unknown arg: $1" ;;
  esac
done

command -v 7z >/dev/null 2>&1 || command -v 7za >/dev/null 2>&1 || die "need p7zip (7z/7za) to extract installers"
SEVENZ="$(command -v 7z 2>/dev/null || command -v 7za)"

DRV="$STAGING/Drivers"
mkdir -p "$DRV"/{chipset,gpu,net,audio} "$STAGING/firmware"

cat >&2 <<'URLS'
================================================================================
 DRIVER SOURCES — download manually into ~/win-kit-staging/  (Cloudflare blocks scripts)
--------------------------------------------------------------------------------
 BIOS   ASUS TUF GAMING B850-E WIFI support page -> BIOS & Firmware
        => drop the .zip in   firmware/   (build-firmware-usb.sh renames to A5653.CAP)
 CHIPSET AMD B850 (AM5) chipset drivers          -> Drivers/chipset/  (AMD_Chipset_Software.exe)
 GPU    AMD Radeon RX 9070 XT Adrenalin (WHQL)   -> Drivers/gpu/
 LAN    Realtek 2.5GbE (ASUS support page)       -> Drivers/net/
 WIFI   MediaTek MT792x Wi-Fi 6E + BT (ASUS)     -> Drivers/net/
 AUDIO  Realtek ALC audio (ASUS support page)    -> Drivers/audio/
 See windows-kit/driver-manifest.md for silent-install switches + install order.
================================================================================
URLS

# Extract any installer archives/exes in a category into a flat driver tree.
extract_cat() {
  local cat="$1"
  local dir="$DRV/$cat"
  local found=0 out
  shopt -s nullglob
  for f in "$dir"/*.exe "$dir"/*.zip "$dir"/*.cab; do
    found=1
    out="$dir/extracted/$(basename "${f%.*}")"
    mkdir -p "$out"
    log "extracting $(basename "$f") -> $out"
    "$SEVENZ" x -y -o"$out" "$f" >/dev/null 2>&1 || log "  (partial/!ok: $(basename "$f"))"
  done
  shopt -u nullglob
  local inf_count
  inf_count=$(find "$dir" -iname '*.inf' 2>/dev/null | wc -l)
  if [[ $found -eq 1 || $inf_count -gt 0 ]]; then
    log "$cat: $inf_count .inf file(s) available"
  else
    log "$cat: empty — drop the vendor download here"
  fi
}

for c in chipset gpu net audio; do extract_cat "$c"; done

if [[ $MAKE_WINPE -eq 1 ]]; then
  WINPE="$STAGING/\$WinpeDriver\$"
  log "assembling \$WinpeDriver\$ from net/ + audio/ -> $WINPE"
  mkdir -p "$WINPE"
  # Copy directories that contain .inf files (Setup recurses this folder).
  while IFS= read -r inf; do
    d="$(dirname "$inf")"
    rel="${d#"$DRV"/}"
    mkdir -p "$WINPE/$rel"
    cp -a "$d"/. "$WINPE/$rel"/ 2>/dev/null || true
  done < <(find "$DRV/net" "$DRV/audio" -iname '*.inf' 2>/dev/null)
  log "\$WinpeDriver\$ ready — pass --payload \"$STAGING\" to write-windows-usb.sh,"
  log "  or copy \$WinpeDriver\$ to the install USB root for first-boot network."
fi

log "Staging dir: $STAGING"
log "Next: write-windows-usb.sh --payload \"$STAGING\"  (copies Drivers/ + Installers/ to the USB)"
