#!/usr/bin/env bash
# Connect to Windows QEMU guest via RustDesk (localhost port forwards).
#
# Usage:
#   ./scripts/rustdesk-windows-qemu.sh
#   WIN_RUSTDESK_PASSWORD='...' ./scripts/rustdesk-windows-qemu.sh
#
# Requires: VM started with --user-net; RustDesk installed in guest.

set -euo pipefail

RD_HOST="${WIN_RUSTDESK_HOST:-127.0.0.1}"
RD_PASSWORD="${WIN_RUSTDESK_PASSWORD:-ChangeMe!RD2026}"
RD_PORT="${WIN_RUSTDESK_PORT:-21116}"

log() { echo "[rustdesk-win] $*" >&2; }
die() { echo "[rustdesk-win] ERROR: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --password) RD_PASSWORD="$2"; shift 2 ;;
    --host)     RD_HOST="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "Unknown arg: $1" ;;
  esac
done

if ! command -v nc >/dev/null 2>&1; then
  die "nc not found"
fi

if ! nc -z -w2 "$RD_HOST" "$RD_PORT" 2>/dev/null; then
  die "RustDesk port ${RD_HOST}:${RD_PORT} not listening — start VM with --user-net and install RustDesk in guest"
fi

if ! command -v rustdesk >/dev/null 2>&1; then
  die "rustdesk not found on host — add to system packages"
fi

log "connecting to ${RD_HOST} (password from WIN_RUSTDESK_PASSWORD)..."
exec rustdesk --connect "${RD_HOST}" --password "${RD_PASSWORD}"
