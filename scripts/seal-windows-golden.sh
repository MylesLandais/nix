#!/usr/bin/env bash
# Seal a verified Windows QEMU install into ~/win-kit-staging/golden/.
#
# Usage:
#   ./scripts/seal-windows-golden.sh --source /tmp/win11-pro-gamer.qcow2
#   ./scripts/seal-windows-golden.sh --source /tmp/win11-pro-gamer.qcow2 \
#       --ovmf-vars /path/to/ovmf-vars.fd --tpm-dir /path/to/swtpm --tag 20260606

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SOURCE=""
TAG="$(date +%Y%m%d)"
GOLDEN_ROOT="${HOME}/win-kit-staging/golden"
OVMF_VARS=""
TPM_DIR=""
VERIFIED="false"
VERIFY_FILE=""

log() { echo "[seal-golden] $*" >&2; }
die() { echo "[seal-golden] ERROR: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)      SOURCE="$2"; shift 2 ;;
    --tag)         TAG="$2"; shift 2 ;;
    --golden-root) GOLDEN_ROOT="$2"; shift 2 ;;
    --ovmf-vars)   OVMF_VARS="$2"; shift 2 ;;
    --tpm-dir)     TPM_DIR="$2"; shift 2 ;;
    --verified)    VERIFIED="true"; shift ;;
    --verify-file) VERIFY_FILE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) die "Unknown arg: $1" ;;
  esac
done

[[ -f "$SOURCE" ]] || die "--source qcow2 required"
command -v qemu-img >/dev/null 2>&1 || die "qemu-img not found"

mkdir -p "$GOLDEN_ROOT"
OUT_QCOW="${GOLDEN_ROOT}/win11-pro-gamer-${TAG}.qcow2"
OUT_VARS="${GOLDEN_ROOT}/ovmf-vars.fd"
OUT_TPM="${GOLDEN_ROOT}/swtpm"
MANIFEST="${GOLDEN_ROOT}/manifest.json"

log "compressing $SOURCE -> $OUT_QCOW"
qemu-img convert -c -O qcow2 "$SOURCE" "$OUT_QCOW"

if [[ -n "$OVMF_VARS" && -f "$OVMF_VARS" ]]; then
  cp "$OVMF_VARS" "$OUT_VARS"
  log "OVMF vars: $OUT_VARS"
fi

if [[ -n "$TPM_DIR" && -d "$TPM_DIR" ]]; then
  rm -rf "$OUT_TPM"
  cp -a "$TPM_DIR" "$OUT_TPM"
  log "swtpm state: $OUT_TPM"
fi

SHA="$(sha256sum "$OUT_QCOW" | awk '{print $1}')"
AUTOUNATTEND_HASH=""
AUTOUNATTEND_FILE="${WINDOWS_KIT_DIR:-$REPO_ROOT/windows-kit}/autounattend.xml"
if [[ -f "$AUTOUNATTEND_FILE" ]]; then
  AUTOUNATTEND_HASH="$(sha256sum "$AUTOUNATTEND_FILE" | awk '{print $1}')"
fi

VERIFY_LINES=""
if [[ -n "$VERIFY_FILE" && -f "$VERIFY_FILE" ]]; then
  VERIFY_LINES="$(sed 's/"/\\"/g' "$VERIFY_FILE" | awk '{printf "%s\\n", $0}')"
  VERIFIED="true"
fi

cat >"$MANIFEST" <<EOF
{
  "tag": "${TAG}",
  "created": "$(date -Iseconds)",
  "qcow2": "$(basename "$OUT_QCOW")",
  "sha256": "${SHA}",
  "autounattend_sha256": "${AUTOUNATTEND_HASH}",
  "verified": ${VERIFIED},
  "verification_summary": "${VERIFY_LINES}"
}
EOF

log "manifest: $MANIFEST"
log "golden image sealed at $OUT_QCOW"
