#!/usr/bin/env bash
# Cerberus pre-flight for remote recovery hardware test.
#
# Usage:
#   ./scripts/recovery-preflight.sh
#   ./scripts/recovery-preflight.sh --host 94tl0m2
#   ./scripts/recovery-preflight.sh --device /dev/sda

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="/dev/sda"
REMOTE_HOST=""
LOG_DIR="${RECOVERY_LOG_DIR:-$REPO_ROOT/.nix-usb-logs}"
mkdir -p "$LOG_DIR" 2>/dev/null || LOG_DIR="/tmp/nix-usb-logs"
mkdir -p "$LOG_DIR"
STAMP=$(date +%Y%m%d-%H%M%S)
OUT="$LOG_DIR/recovery-preflight-$STAMP.log"

log() { echo "[recovery-preflight] $*" | tee -a "$OUT"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device) DEVICE="$2"; shift 2 ;;
    --host)   REMOTE_HOST="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,8p' "$0"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

mkdir -p "$LOG_DIR"

log "=== lacie layout ==="
lsblk -f "$DEVICE" | tee -a "$OUT"

log "=== ISO on lacie_isos ==="
ISOS_PART=$(blkid -L lacie_isos 2>/dev/null || echo "${DEVICE}2")
ISOS_MNT=$(findmnt -n -o TARGET "$ISOS_PART" 2>/dev/null || true)
if [[ -n "$ISOS_MNT" ]]; then
  log "already mounted at $ISOS_MNT"
  ls -lh "$ISOS_MNT"/*.iso 2>/dev/null | tee -a "$OUT" || log "WARNING: no ISO files"
else
  MNT=""
  if MNT=$(udisksctl mount -b "$ISOS_PART" 2>&1 | sed -n 's/.*at \(\/[^ ]*\).*/\1/p'); then
    ls -lh "$MNT"/*.iso 2>/dev/null | tee -a "$OUT" || log "WARNING: no ISO files on $ISOS_PART"
    udisksctl unmount -b "$ISOS_PART" >/dev/null 2>&1 || true
  else
    log "WARNING: could not mount $ISOS_PART — $MNT"
  fi
fi

log "=== GRUB iso-entries.cfg ==="
EFI_PART=$(blkid -L LACIE_EFI 2>/dev/null || echo "${DEVICE}1")
EFI_MNT=$(findmnt -n -o TARGET "$EFI_PART" 2>/dev/null || true)
if [[ -n "$EFI_MNT" ]]; then
  log "already mounted at $EFI_MNT"
  MNT="$EFI_MNT"
else
  MNT=""
  MNT=$(udisksctl mount -b "$EFI_PART" 2>&1 | sed -n 's/.*at \(\/[^ ]*\).*/\1/p') || true
fi
if [[ -n "$MNT" && -f "$MNT/boot/grub/iso-entries.cfg" ]]; then
  grep -E 'menuentry|configfile|iso_path|home-office' "$MNT/boot/grub/iso-entries.cfg" | tee -a "$OUT"
  [[ -z "$EFI_MNT" ]] && udisksctl unmount -b "$EFI_PART" >/dev/null 2>&1 || true
elif [[ -n "$MNT" ]]; then
  log "WARNING: missing iso-entries.cfg on $EFI_PART"
  [[ -z "$EFI_MNT" ]] && udisksctl unmount -b "$EFI_PART" >/dev/null 2>&1 || true
else
  log "WARNING: could not mount $EFI_PART"
fi

log "=== QEMU dry-run ==="
if [[ -x "$REPO_ROOT/scripts/test-usb-qemu.sh" ]]; then
  sudo -n "$REPO_ROOT/scripts/test-usb-qemu.sh" --dry-run --partitions --serial --auto-device 2>&1 | tee -a "$OUT" \
    || log "NOTE: dry-run needs sudo (or run manually)"
fi

log "=== SSH baseline ==="
if [[ -z "$REMOTE_HOST" ]]; then
  for h in 94tl0m2 95qmom2; do
    log "--- $h ---"
  if ssh -o ConnectTimeout=5 -o BatchMode=yes "$h" \
    'echo "host=$(hostname)"; lsblk -f; echo "serial=$(sudo dmidecode -s system-serial-number 2>/dev/null)"' 2>&1 | tee -a "$OUT"; then
      log "$h: SSH OK"
    else
      log "$h: SSH failed (unlock Bitwarden SSH agent or check keys)"
    fi
  done
else
  log "--- $REMOTE_HOST ---"
  ssh -o ConnectTimeout=5 -o BatchMode=yes "$REMOTE_HOST" \
    'echo "host=$(hostname)"; lsblk -f; echo "serial=$(sudo dmidecode -s system-serial-number 2>/dev/null)"' 2>&1 | tee -a "$OUT" \
    || log "$REMOTE_HOST: SSH failed"
fi

log "=== static baseline (hw-config) ==="
cat >> "$OUT" <<'EOF'
94tl0m2: root LABEL=nixos (nvme), boot LABEL=BOOT, data LABEL=data on sda
95qmom2: root sda3 ext4, boot sda1, data sdb1 XFS; LAN 192.168.0.49, TS dell-potato
EOF

log "Log: $OUT"
log "Next: plug lacie into OptiPlex, F12 boot, then ./scripts/recovery-verify.sh --host <dhcp-ip>"
