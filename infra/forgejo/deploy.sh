#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
target=${FORGEJO_TARGET:-root@100.123.116.99}
ssh_options=(-C -o BatchMode=yes -o StrictHostKeyChecking=yes -o HostKeyAlias=stage-db)
export NIX_SSHOPTS="${NIX_SSHOPTS:-} -C -o BatchMode=yes -o StrictHostKeyChecking=yes -o HostKeyAlias=stage-db"
env_file=${1:-"$repo/infra/forgejo/.env.tf"}
if [ "$env_file" != --prepare ]; then
  test -s "$env_file" || { echo "Missing OpenTofu environment file: $env_file" >&2; exit 1; }
  grep -q '^TUNNEL_TOKEN=.' "$env_file"
  grep -qx 'DOMAIN=git.nebula-1.com' "$env_file"
  # Stage under a private directory on the same filesystem, then rename atomically.
  ssh "${ssh_options[@]}" "$target" 'set -eu; umask 077; install -d -m 0700 /etc/forgejo; tmp=$(mktemp /etc/forgejo/.env.tf.XXXXXX); trap '\''rm -f "$tmp"'\'' EXIT; cat > "$tmp"; test -s "$tmp"; chmod 0600 "$tmp"; mv -f "$tmp" /etc/forgejo/.env.tf' < "$env_file"
fi
# Evaluation happens locally; all architecture-dependent builds run on the ARM host.
nixos-rebuild dry-activate --flake "$repo#stage-db" --build-host "$target" --target-host "$target"
# Retain a timed recovery path in case changing networking interrupts SSH.
ssh "${ssh_options[@]}" "$target" bash -s <<'REMOTE'
set -eu
previous=$(readlink /run/current-system)
systemd-run --unit=forgejo-deploy-rollback --on-active=15m /run/current-system/sw/bin/bash -c 'nix-env -p /nix/var/nix/profiles/system --set "$1"; exec "$1/bin/switch-to-configuration" switch' rollback "$previous"
REMOTE
nixos-rebuild switch --flake "$repo#stage-db" --build-host "$target" --target-host "$target"
ssh "${ssh_options[@]}" "$target" 'set -eu; systemctl restart forgejo.service; systemctl start forgejo-tunnel.service; systemctl --no-pager --full status forgejo.service; /etc/forgejo/compose ps'
ssh "${ssh_options[@]}" "$target" 'systemctl stop forgejo-deploy-rollback.timer'
