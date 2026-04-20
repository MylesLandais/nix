#!/usr/bin/env bash
set -euo pipefail

flake="$(dirname "$(readlink -f "$0")")/../flake.nix"
latest=$(curl -sSL https://api.github.com/repos/NousResearch/hermes-agent/releases/latest | jq -r .tag_name)

if [[ -z "$latest" || "$latest" == "null" ]]; then
  echo "failed to resolve latest hermes-agent tag" >&2
  exit 1
fi

current=$(grep -oE 'hermes-agent.url = "github:NousResearch/hermes-agent/[^"]+' "$flake" | sed 's|.*/||')
if [[ "$current" == "$latest" ]]; then
  echo "hermes-agent already pinned to ${latest}"
  exit 0
fi

sed -i -E "s|(hermes-agent.url = \"github:NousResearch/hermes-agent/)[^\"]+|\1${latest}|" "$flake"
nix flake lock --update-input hermes-agent --flake "$(dirname "$flake")"
echo "hermes-agent bumped: ${current} -> ${latest}"
