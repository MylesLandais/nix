#!/usr/bin/env bash
# Build the hypr-v Hyper-V VHDX image and copy it to a user-chosen path.
#
# Usage: scripts/build-hypr-v.sh [output-path]
# Default output: ./hypr-v.vhdx

set -euo pipefail

cd "$(dirname "$0")/.."

OUT="${1:-./hypr-v.vhdx}"

echo "Building .#packages.x86_64-linux.hypr-v..."
nix build .#packages.x86_64-linux.hypr-v --print-out-paths -L

SRC="$(find -L result -maxdepth 3 -type f -name '*.vhdx' -print -quit)"
if [ -z "${SRC:-}" ]; then
  echo "error: no .vhdx file found under result/" >&2
  ls -lR result/ >&2 || true
  exit 1
fi

cp --reflink=auto "$SRC" "$OUT"
chmod u+w "$OUT"

SIZE="$(du -h "$OUT" | cut -f1)"
echo "Wrote $OUT ($SIZE)"
