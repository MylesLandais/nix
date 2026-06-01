#!/usr/bin/env bash
# Reproducible installer ISO build + stage + GRUB refresh, with optional
# Tier 4 QEMU SSH smoke gate. Single-command replacement for the four-step
# build/stage/grub/test loop documented in docs/cluster/installer-iso.md.
#
# Usage:
#   nix run .#iso-deploy -- --device /dev/sda
#   nix run .#iso-deploy -- --device /dev/sda --smoke
#   nix run .#iso-deploy -- --device /dev/sda --skip-build /tmp/.../iso/*.iso
#
# Options:
#   --device /dev/sdX     Lacie disk (default: /dev/sda)
#   --smoke               After staging, run Tier 4 QEMU SSH smoke
#   --skip-build          Use an existing ISO path argument; do not rebuild
#   --no-grub             Skip setup-nix-usb.sh --grub-only (only stage)
#   --flake URI           Flake to build (default: .)
#   --attr ATTR           Output attr (default: packages.x86_64-linux.installer-iso)
#   --ssh-key PATH        Identity for Tier 4 (default: ~/.ssh/id_ed25519)
#   --ssh-user USER       SSH user for Tier 4 (default: warby)
#   --ssh-timeout SEC     Tier 4 wait budget (default: 300)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEVICE="/dev/sda"
DO_SMOKE=0
SKIP_BUILD=0
SKIP_GRUB=0
FLAKE_URI="."
ATTR="packages.x86_64-linux.installer-iso"
SSH_KEY="${HOME:-/home/warby}/.ssh/id_ed25519"
SSH_USER="warby"
SSH_TIMEOUT=300
ISO_ARG=""

log() { echo "[iso-deploy] $*" >&2; }
die() { echo "[iso-deploy] ERROR: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --device)       DEVICE="$2"; shift 2 ;;
    --smoke)        DO_SMOKE=1; shift ;;
    --skip-build)   SKIP_BUILD=1; shift ;;
    --no-grub)      SKIP_GRUB=1; shift ;;
    --flake)        FLAKE_URI="$2"; shift 2 ;;
    --attr)         ATTR="$2"; shift 2 ;;
    --ssh-key)      SSH_KEY="$2"; shift 2 ;;
    --ssh-user)     SSH_USER="$2"; shift 2 ;;
    --ssh-timeout)  SSH_TIMEOUT="$2"; shift 2 ;;
    -h|--help)      sed -n '2,22p' "$0"; exit 0 ;;
    --)             shift; break ;;
    *)              [[ -z "$ISO_ARG" ]] && ISO_ARG="$1" && shift && continue
                    die "Unknown arg: $1" ;;
  esac
done

GIT_REV="$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
GIT_DIRTY=""
if ! git -C "$REPO_ROOT" diff --quiet 2>/dev/null \
  || ! git -C "$REPO_ROOT" diff --cached --quiet 2>/dev/null; then
  GIT_DIRTY=" (dirty)"
fi
log "git: $GIT_REV$GIT_DIRTY  device: $DEVICE  smoke: $DO_SMOKE  skip-build: $SKIP_BUILD"

ISO_PATH=""
if [[ $SKIP_BUILD -eq 1 ]]; then
  [[ -n "$ISO_ARG" && -f "$ISO_ARG" ]] || die "--skip-build requires existing ISO path arg"
  ISO_PATH="$ISO_ARG"
  log "skip-build: using $ISO_PATH"
else
  RESULT_LINK="$REPO_ROOT/result-installer-iso"
  log "build: nix build $FLAKE_URI#$ATTR -> $RESULT_LINK"
  cd "$REPO_ROOT"
  if ! nix build "$FLAKE_URI#$ATTR" -o "$RESULT_LINK"; then
    die "nix build failed"
  fi
  shopt -s nullglob
  _matches=( "$RESULT_LINK"/iso/*.iso )
  shopt -u nullglob
  ((${#_matches[@]})) || die "build succeeded but no ISO in $RESULT_LINK/iso/"
  ISO_PATH="${_matches[0]}"
  log "built ISO: $ISO_PATH ($(stat -c %s "$ISO_PATH") bytes)"
fi

ISO_SIZE_HUMAN=$(numfmt --to=iec --suffix=B "$(stat -c %s "$ISO_PATH")" 2>/dev/null \
  || stat -c '%s bytes' "$ISO_PATH")
log "iso size: $ISO_SIZE_HUMAN"

log "stage: $REPO_ROOT/scripts/stage-installer-iso.sh --device $DEVICE $ISO_PATH"
if [[ $EUID -ne 0 ]]; then
  sudo "$REPO_ROOT/scripts/stage-installer-iso.sh" --device "$DEVICE" "$ISO_PATH"
else
  "$REPO_ROOT/scripts/stage-installer-iso.sh" --device "$DEVICE" "$ISO_PATH"
fi

if [[ $SKIP_GRUB -eq 1 ]]; then
  log "skip-grub: not running setup-nix-usb.sh --grub-only"
fi

SMOKE_RESULT="skipped"
if [[ $DO_SMOKE -eq 1 ]]; then
  log "smoke: Tier 4 QEMU SSH smoke (this boots the full ISO in QEMU)"
  smoke_cmd=(
    "$REPO_ROOT/scripts/test-usb-qemu.sh"
    --ssh-smoke
    --auto-device
    --ssh-key "$SSH_KEY"
    --ssh-user "$SSH_USER"
    --ssh-timeout "$SSH_TIMEOUT"
  )
  # Tier 4 only needs disk/kvm group access, not sudo — and running as the
  # real user keeps SSH_AGENT_SOCK / Bitwarden agent reachable for the smoke.
  if [[ $EUID -ne 0 ]] && ! { id -nG | tr ' ' '\n' | grep -qx disk; }; then
    smoke_cmd=(sudo -E "${smoke_cmd[@]}")
  fi
  if "${smoke_cmd[@]}"; then
    SMOKE_RESULT="PASS"
  else
    SMOKE_RESULT="FAIL"
    log "Tier 4 SSH smoke FAILED — ISO is staged but not verified"
    log "Inspect serial log under /tmp/*-tier4-qemu.log before flashing"
  fi
fi

cat <<EOF
[iso-deploy] summary
====================
git rev:    $GIT_REV$GIT_DIRTY
iso path:   $ISO_PATH
iso size:   $ISO_SIZE_HUMAN
device:     $DEVICE
smoke:      $SMOKE_RESULT
EOF

case "$SMOKE_RESULT" in
  FAIL) exit 1 ;;
  *)    exit 0 ;;
esac
