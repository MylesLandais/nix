#!/usr/bin/env bash
# Verify recovery SSH from cerberus to a live installer session.
#
# Usage:
#   ./scripts/recovery-verify.sh --host 192.168.0.212
#   ./scripts/recovery-verify.sh --host 192.168.0.212 --root LABEL=nixos
#   ./scripts/recovery-verify.sh --host 192.168.0.49 --root /dev/sda3 --user root
#
# Runs remote read-only checks: SSH login, optional mount + nixos-enter dry-run.

set -euo pipefail

HOST=""
USER="warby"
ROOT_SPEC=""
DO_ENTER=0
STAMP=$(date +%Y%m%d-%H%M%S)
LOG_DIR="${RECOVERY_LOG_DIR:-$(cd "$(dirname "$0")/.." && pwd)/.nix-usb-logs}"
mkdir -p "$LOG_DIR" 2>/dev/null || LOG_DIR="/tmp/nix-usb-logs"
mkdir -p "$LOG_DIR"
OUT="$LOG_DIR/recovery-verify-$STAMP.log"

log() { echo "[recovery-verify] $*" | tee -a "$OUT"; }
pass() { log "PASS: $*"; }
fail() { log "FAIL: $*"; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)      HOST="$2"; shift 2 ;;
    --user)      USER="$2"; shift 2 ;;
    --root)      ROOT_SPEC="$2"; shift 2 ;;
    --enter)     DO_ENTER=1; shift ;;
    -h|--help)
      sed -n '2,10p' "$0"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$HOST" ]] || fail "Pass --host <ip-or-hostname>"

mkdir -p "$LOG_DIR"
log "target: $USER@$HOST root=${ROOT_SPEC:-none} enter=$DO_ENTER"

ssh_opts=(-o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new)

log "=== SSH as $USER ==="
if ssh "${ssh_opts[@]}" "$USER@$HOST" 'hostname; ip -4 addr show scope global; systemctl is-system-running 2>/dev/null || true' 2>&1 | tee -a "$OUT"; then
  pass "SSH $USER@$HOST"
else
  log "Trying root@$HOST ..."
  if ssh "${ssh_opts[@]}" root@"$HOST" 'hostname; ip -4 addr show scope global' 2>&1 | tee -a "$OUT"; then
    pass "SSH root@$HOST"
    USER=root
  else
    fail "SSH to $HOST (unlock Bitwarden agent?)"
  fi
fi

if [[ -n "$ROOT_SPEC" ]]; then
  log "=== mount + nixos-enter on $ROOT_SPEC ==="
  remote_script=$(cat <<REMOTE
set -e
ROOT="$ROOT_SPEC"
if [[ "\$ROOT" == LABEL=* ]]; then
  DEV="/dev/disk/by-label/\${ROOT#LABEL=}"
else
  DEV="\$ROOT"
fi
lsblk -f "\$DEV" || lsblk -f
sudo mount -o ro "\$DEV" /mnt
echo "mounted \$(findmnt -n -o SOURCE /mnt)"
if [[ $DO_ENTER -eq 1 ]]; then
  sudo nixos-enter --root /mnt -- bash -c 'echo enter_ok; nixos-version 2>/dev/null || cat /etc/os-release | head -1'
fi
sudo umount /mnt
echo umount_ok
REMOTE
)
  if ssh "${ssh_opts[@]}" "$USER@$HOST" "bash -s" <<< "$remote_script" 2>&1 | tee -a "$OUT"; then
    pass "mount/nixos-enter on $ROOT_SPEC"
  else
    fail "mount/nixos-enter on $ROOT_SPEC"
  fi
fi

log "Log: $OUT"
log "Recovery verification complete. Reboot target off lacie and confirm normal SSH."
