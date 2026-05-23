#!/usr/bin/env bash
# bootstrap-lacie.sh
# Installs NixOS onto the LaCie live_nix partition from a live ISO session.
# Run this after booting the NixOS installer ISO on the LaCie (via GRUB or Ventoy).
#
# Usage:
#   sudo ./bootstrap-lacie.sh
#   sudo ./bootstrap-lacie.sh --dry-run
#   sudo ./bootstrap-lacie.sh --skip-clone
#   sudo ./bootstrap-lacie.sh --device /dev/sdb

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
DRY_RUN=0
SKIP_CLONE=0
DEVICE=""
REPO_URL="https://github.com/MylesLandais/nix.git"
FLAKE_TARGET="lacie"
MNT="/mnt"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

log()  { echo "  >> $*"; }
step() { echo; echo "==> $*"; }
die()  { echo "ERROR: $*" >&2; exit 1; }
run()  { if [[ $DRY_RUN -eq 1 ]]; then echo "    [dry-run] $*"; else "$@"; fi; }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)     DRY_RUN=1; shift ;;
    --skip-clone)  SKIP_CLONE=1; shift ;;
    --device)      DEVICE="${2:-}"; shift 2 ;;
    -h|--help)
      echo "Usage: sudo $SCRIPT_NAME [--dry-run] [--skip-clone] [--device /dev/sdX]"
      exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

[[ $EUID -eq 0 ]] || die "Run with sudo."
[[ $DRY_RUN -eq 1 ]] && echo "  (dry-run mode — no changes will be made)"

# ---------------------------------------------------------------------------
# Phase 1: Preflight
# ---------------------------------------------------------------------------

step "Phase 1: Preflight checks"

# Detect LaCie by labels if --device not provided
if [[ -z "$DEVICE" ]]; then
  log "Auto-detecting LaCie by partition labels..."
  LIVE_DEV="$(blkid -L live_nix 2>/dev/null || true)"
  [[ -n "$LIVE_DEV" ]] || die "Could not find partition LABEL=live_nix. Is the LaCie connected?"
  DEVICE="$(lsblk -no PKNAME "$LIVE_DEV" | head -1)"
  DEVICE="/dev/${DEVICE}"
  log "Detected: $DEVICE"
fi

[[ -b "$DEVICE" ]] || die "Not a block device: $DEVICE"

log "Checking required partitions..."
# Support both the new GRUB layout (LACIE_EFI) and legacy Ventoy layout (VTOYEFI).
EFI_DEV="$(blkid -L LACIE_EFI 2>/dev/null || blkid -L VTOYEFI 2>/dev/null || true)"
LIVE_DEV="$(blkid -L live_nix 2>/dev/null || true)"
DATA_DEV="$(blkid -L persistent_data 2>/dev/null || true)"

[[ -n "$EFI_DEV" ]]  || die "EFI partition not found (expected LACIE_EFI or VTOYEFI). Run setup-nix-usb.sh first."
[[ -n "$LIVE_DEV" ]] || die "live_nix partition not found. Run setup-nix-usb.sh first."
[[ -n "$DATA_DEV" ]] || die "persistent_data partition not found. Run setup-nix-usb.sh first."

log "Partitions: EFI=$EFI_DEV  live_nix=$LIVE_DEV  persistent_data=$DATA_DEV"

log "Checking network..."
if curl -sf --max-time 5 https://cache.nixos.org > /dev/null; then
  log "Network: OK"
else
  die "No connectivity to cache.nixos.org. Connect to a network before continuing."
fi

lsblk -o NAME,SIZE,FSTYPE,LABEL "$DEVICE"
echo
read -r -p "Install NixOS onto $LIVE_DEV (LABEL=live_nix)? [yes/N] " CONFIRM
[[ "$CONFIRM" == "yes" ]] || exit 1

# ---------------------------------------------------------------------------
# Phase 2: Mount
# ---------------------------------------------------------------------------

step "Phase 2: Mounting partitions"

run mkdir -p "$MNT"
run mkdir -p "$MNT/boot"
run mkdir -p "$MNT/data"

mountpoint -q "$MNT"      || run mount "$LIVE_DEV" "$MNT"
mountpoint -q "$MNT/boot" || run mount "$EFI_DEV"  "$MNT/boot"
mountpoint -q "$MNT/data" || run mount "$DATA_DEV"    "$MNT/data" 2>/dev/null || log "Warning: persistent_data mount failed (NTFS driver may be missing in live ISO — continuing)"

log "Mounts:"
mount | grep "$MNT" | awk '{print "   " $0}' || true

# ---------------------------------------------------------------------------
# Phase 3: Hardware configuration
# ---------------------------------------------------------------------------

step "Phase 3: Generating hardware-configuration.nix"

run nixos-generate-config --root "$MNT" --no-filesystems

GENERATED="/etc/nixos/hardware-configuration.nix"
TARGET="$MNT/nix-configs/hosts/lacie/hardware-configuration.nix"

if [[ $DRY_RUN -eq 0 ]]; then
  if [[ -f "$GENERATED" ]]; then
    log "Generated: $GENERATED"
    if [[ -f "$TARGET" ]]; then
      echo "--- Diff against current stub ---"
      diff "$TARGET" "$GENERATED" || true
      echo "--- End diff ---"
    fi
  else
    log "Warning: nixos-generate-config did not produce $GENERATED"
  fi
fi

# ---------------------------------------------------------------------------
# Phase 4: Repository
# ---------------------------------------------------------------------------

step "Phase 4: Config repository"

REPO_PATH="$MNT/nix-configs"

if [[ $SKIP_CLONE -eq 1 ]]; then
  log "--skip-clone set; skipping git clone/pull"
  [[ -d "$REPO_PATH/.git" ]] || die "No repo found at $REPO_PATH and --skip-clone is set."
else
  if [[ -d "$REPO_PATH/.git" ]]; then
    log "Repo exists — pulling latest..."
    run git -C "$REPO_PATH" fetch origin
    run git -C "$REPO_PATH" pull --ff-only origin main
  else
    log "Cloning $REPO_URL..."
    run git clone "$REPO_URL" "$REPO_PATH"
  fi
fi

if [[ $DRY_RUN -eq 0 ]]; then
  # Copy generated hardware config into repo
  if [[ -f "$GENERATED" ]]; then
    cp "$GENERATED" "$TARGET"
    log "Copied hardware-configuration.nix to $TARGET"
  fi

  # Confirm flake target exists
  nix flake show "$REPO_PATH" 2>/dev/null | grep -q "$FLAKE_TARGET" \
    || die "Flake target '$FLAKE_TARGET' not found in $REPO_PATH. Check the repo."
  log "Flake target '$FLAKE_TARGET' confirmed."
fi

# ---------------------------------------------------------------------------
# Phase 5: Install
# ---------------------------------------------------------------------------

step "Phase 5: NixOS install"

log "Running: nixos-install --flake $REPO_PATH#$FLAKE_TARGET --root $MNT --no-root-passwd"
run nixos-install \
  --flake "$REPO_PATH#$FLAKE_TARGET" \
  --root "$MNT" \
  --no-root-passwd

# ---------------------------------------------------------------------------
# Phase 6: Post-install summary
# ---------------------------------------------------------------------------

step "Phase 6: Done"

cat <<EOF

Install complete. Before rebooting:

  1. Add your Hermes API key so the AI assistant works on first boot:
       mkdir -p $MNT/data/secrets
       echo 'ANTHROPIC_API_KEY=sk-ant-...' > $MNT/data/secrets/hermes.env
       chmod 600 $MNT/data/secrets/hermes.env

  2. Eject the LaCie safely:
       umount -R $MNT

  3. Reboot and press F12 at POST to open the firmware boot menu.
     Select the UEFI USB entry. The Kanagawa GRUB menu will appear.
     Secure Boot must be OFF. UEFI mode required.

  4. After first boot, rebuild to apply any pending changes:
       sudo nixos-rebuild switch --flake /nix-configs#lacie

  5. SSH and git auth:
     Copy your private key to ~/.ssh/ or set up Tailscale for vault access.
     See hosts/lacie/README.md for the vault trust bootstrap plan.

EOF
