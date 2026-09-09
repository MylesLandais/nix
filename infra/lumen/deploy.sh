#!/usr/bin/env bash
# Deploy a pinned Lumen release to stage-edge over the tailnet.
# Mirrors infra/forgejo/deploy.sh: evaluate locally, build on the ARM host,
# keep a timed rollback in case networking changes interrupt SSH.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
target=${LUMEN_TARGET:-root@100.113.209.112}
ssh_options=(-C -o BatchMode=yes -o StrictHostKeyChecking=yes -o HostKeyAlias=stage-edge)
export NIX_SSHOPTS="${NIX_SSHOPTS:-} -C -o BatchMode=yes -o StrictHostKeyChecking=yes -o HostKeyAlias=stage-edge"
env_file=${1:-"$repo/infra/lumen/.env.tunnel"}
if [ "$env_file" != --prepare ]; then
  test -s "$env_file" || { echo "Missing tunnel environment file: $env_file" >&2; exit 1; }
  grep -q '^TUNNEL_TOKEN=.' "$env_file"
  # Stage under a private directory on the same filesystem, then rename atomically.
  # The file ships verbatim: systemd loads it as EnvironmentFile (TUNNEL_TOKEN=...).
  ssh "${ssh_options[@]}" "$target" 'set -eu; umask 077; install -d -m 0700 /etc/lumen; tmp=$(mktemp /etc/lumen/.env.tunnel.XXXXXX); trap '\''rm -f "$tmp"'\'' EXIT; cat > "$tmp"; test -s "$tmp"; grep -q "^TUNNEL_TOKEN=." "$tmp"; chmod 0600 "$tmp"; mv -f "$tmp" /etc/lumen/.env.tunnel' < "$env_file"
fi
# Evaluation happens locally; all architecture-dependent builds run on the ARM host.
nixos-rebuild dry-activate --flake "$repo#stage-edge" --build-host "$target" --target-host "$target"
# Retain a timed recovery path in case changing networking interrupts SSH.
ssh "${ssh_options[@]}" "$target" bash -s <<'REMOTE'
set -eu
previous=$(readlink /run/current-system)
systemd-run --unit=lumen-deploy-rollback --on-active=15m /run/current-system/sw/bin/bash -c 'nix-env -p /nix/var/nix/profiles/system --set "$1"; exec "$1/bin/switch-to-configuration" switch' rollback "$previous"
REMOTE
nixos-rebuild switch --flake "$repo#stage-edge" --build-host "$target" --target-host "$target"
ssh "${ssh_options[@]}" "$target" 'set -eu; systemctl restart lumen-lab.service; systemctl start lumen-tunnel.service; systemctl --no-pager --full status lumen-lab.service lumen-tunnel.service'
ssh "${ssh_options[@]}" "$target" 'systemctl stop lumen-deploy-rollback.timer'
