#!/usr/bin/env bash
# Deploy stage-edge (Penpot). Same SSH contract as infra/forgejo/deploy.sh:
# known_hosts pins these hosts by name, not tailnet IP, hence HostKeyAlias.
# One multiplexed connection, so Bitwarden asks to approve the key only once.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
target=${PENPOT_TARGET:-root@100.113.209.112}
control=${XDG_RUNTIME_DIR:-/tmp}/ssh-stage-edge
ssh_options=(-C -o BatchMode=yes -o StrictHostKeyChecking=yes -o HostKeyAlias=stage-edge
  -o ControlMaster=auto -o "ControlPath=$control" -o ControlPersist=30m)
export NIX_SSHOPTS="${NIX_SSHOPTS:-} ${ssh_options[*]}"
ssh "${ssh_options[@]}" "$target" true
nixos-rebuild switch --flake "$repo#stage-edge" --target-host "$target" --build-host "$target"
ssh "${ssh_options[@]}" "$target" 'systemctl --no-pager status penpot.service penpot-serve.service; /etc/penpot/compose ps'
