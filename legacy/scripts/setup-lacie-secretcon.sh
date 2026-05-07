#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[setup-lacie-secretcon] Deprecated: use setup-nix-usb.sh instead." >&2
exec "${SCRIPT_DIR}/setup-nix-usb.sh" "$@"
