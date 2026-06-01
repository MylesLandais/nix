#!/usr/bin/env bash
# Build installerIso toplevel (no 14 GB ISO packaging) and print Tier 1 test command.
#
# Usage:
#   ./scripts/extract-installer-boot.sh
#   ./scripts/extract-installer-boot.sh --build   # force nix build
#   ./scripts/extract-installer-boot.sh --out /tmp/installer-toplevel
#
# Boot-path iteration loop:
#   1. Edit modules/hosts/installer-iso/default.nix (initrd, kernel modules, etc.)
#   2. ./scripts/extract-installer-boot.sh --build
#   3. Run the printed sudo test-usb-qemu.sh command (Tier 1)
#   4. On pass: setup-nix-usb.sh --grub-only → Tier 2
#   5. Full ISO rebuild only before staging to hardware

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_LINK="/tmp/installer-toplevel"
DO_BUILD=0
FINDISO="/home-office-installer.iso"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build)   DO_BUILD=1; shift ;;
    --out)     OUT_LINK="$2"; shift 2 ;;
    --findiso) FINDISO="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,15p' "$0"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

ATTR=".#nixosConfigurations.installerIso.config.system.build.toplevel"

if [[ $DO_BUILD -eq 1 ]] || [[ ! -e "$OUT_LINK" ]]; then
  echo "[extract-installer-boot] building $ATTR ..." >&2
  nix build "$REPO_ROOT$ATTR" -o "$OUT_LINK"
else
  echo "[extract-installer-boot] reusing $OUT_LINK (pass --build to rebuild)" >&2
fi

resolve_boot_artifacts() {
  local root="$1"
  local kernel initrd

  if [[ -e "$root/kernel" && -e "$root/initrd" ]]; then
    kernel=$(readlink -f "$root/kernel")
    initrd=$(readlink -f "$root/initrd")
  else
    kernel=$(find "$root/boot" -name bzImage -print -quit 2>/dev/null || true)
    initrd=$(find "$root/boot" -name initrd -print -quit 2>/dev/null || true)
    [[ -z "$initrd" && -f "$root/boot/initrd" ]] && initrd="$root/boot/initrd"
  fi

  [[ -n "$kernel" && -f "$kernel" && -n "$initrd" && -f "$initrd" ]] || return 1
  printf '%s\n%s\n' "$kernel" "$initrd"
}

mapfile -t _boot < <(resolve_boot_artifacts "$OUT_LINK") || {
  echo "[extract-installer-boot] ERROR: boot artifacts not found under $OUT_LINK" >&2
  exit 1
}
KERNEL="${_boot[0]}"
INITRD="${_boot[1]}"

echo "[extract-installer-boot] kernel: $KERNEL" >&2
echo "[extract-installer-boot] initrd: $INITRD ($(stat -c %s "$INITRD") bytes)" >&2
echo >&2

cat <<EOF
# Tier 1 — test findiso with fresh initrd (no full ISO rebuild):
sudo $REPO_ROOT/scripts/test-usb-qemu.sh --iso-only --serial --auto-device \\
  --kernel "$KERNEL" \\
  --initrd "$INITRD" \\
  --findiso "$FINDISO" \\
  --log-file /tmp/tier1.log

# Optional: auto-pass when Stage 1 appears:
#   ... --expect 'Stage 1' --timeout 300
EOF
