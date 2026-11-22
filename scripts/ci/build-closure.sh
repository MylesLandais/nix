#!/usr/bin/env bash
# CI build of every flake package plus the Cerberus system closure.
#
# Builds with --keep-going so one broken derivation doesn't stop the rest from
# reaching the binary cache. A failure only fails the job when it comes from
# something other than a volatile vendor download: those publish a mutable
# `latest` URL, so their pinned hash goes stale between bumps
# (pkgs/<name>/update.sh fixes them on Cerberus).
set -uo pipefail

volatile='chatgpt_amd64\.deb'

mapfile -t pkgs < <(nix eval --json .#packages.x86_64-linux --apply builtins.attrNames | jq -r '.[]')
targets=()
for p in "${pkgs[@]}"; do targets+=(".#packages.x86_64-linux.$p"); done

log=$(mktemp)
nix build --keep-going --no-link --print-build-logs "${targets[@]}" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
[ "$status" -eq 0 ] && exit 0

# Derivations whose own builder failed (not "dependency failed" cascades).
mapfile -t failed < <(grep -oE "(builder for|hash mismatch in fixed-output derivation) '/nix/store/[^']+\.drv'" "$log" |
  grep -oE "/nix/store/[^']+\.drv" | sort -u)

if [ "${#failed[@]}" -eq 0 ]; then
  echo "::error::nix build failed without a failed builder (evaluation or infrastructure error)"
  exit "$status"
fi

real=0
for drv in "${failed[@]}"; do
  if [[ $drv =~ $volatile ]]; then
    echo "::warning::volatile vendor download is stale: $drv (run its update.sh)"
  else
    echo "::error::build failed: $drv"
    real=1
  fi
done
exit "$real"
