#!/usr/bin/env bash
# Refresh assets/kali/ from a Kali QEMU .7z release.
# Usage: ./scripts/extract-kali-artifacts.sh /path/to/kali-linux-XXXX.X-qemu-amd64.7z
set -euo pipefail

ARCHIVE="${1:?usage: $0 <kali-qemu-amd64.7z>}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
MNT="$(mktemp -d)"
trap 'guestunmount "$MNT" 2>/dev/null || true; rm -rf "$WORK" "$MNT"' EXIT

echo "Extracting qcow2..."
nix shell nixpkgs#p7zip -c 7z x "$ARCHIVE" -o"$WORK" -y >/dev/null
QCOW=$(find "$WORK" -name '*.qcow2' | head -1)

echo "Mounting $QCOW (read-only)..."
nix shell nixpkgs#libguestfs-with-appliance -c guestmount -a "$QCOW" -i --ro "$MNT"

DEST="$REPO/assets/kali"
echo "Copying artifacts to $DEST..."
rm -rf "$DEST"
mkdir -p "$DEST"/{themes,backgrounds,xdg,applications,desktop-base}
cp -r "$MNT/usr/share/themes/Kali-Dark" "$DEST/themes/"
cp -r "$MNT/usr/share/backgrounds/kali" "$DEST/backgrounds/"
cp -r "$MNT/etc/xdg/xfce4" "$DEST/xdg/"
cp -r "$MNT/usr/share/desktop-base/kali-theme" "$DEST/desktop-base/"
cp "$MNT"/usr/share/applications/kali-*.desktop "$DEST/applications/"

mkdir -p "$DEST/skel"
cp "$MNT/etc/skel/.bashrc" "$DEST/skel/bashrc"
cp "$MNT/etc/skel/.bash_logout" "$DEST/skel/bash_logout"
cp "$MNT/etc/skel/.zshrc" "$DEST/skel/zshrc"
cp "$MNT/etc/skel/.zprofile" "$DEST/skel/zprofile"
cp "$MNT/etc/skel/.profile" "$DEST/skel/profile"
cp "$MNT/etc/skel/.face" "$DEST/skel/face"
cp "$MNT/etc/xdg/mimeapps.list" "$DEST/skel/mimeapps.list"

du -sh "$DEST"
echo "Done. Review changes with: git status assets/kali"
