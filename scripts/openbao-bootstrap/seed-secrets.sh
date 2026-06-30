#!/usr/bin/env bash
# Interactive seed of Discord + pyLoad credentials into OpenBao KV.
set -euo pipefail

: "${OPENBAO_ADDR:=http://127.0.0.1:8200}"
: "${OPENBAO_TOKEN:?Set OPENBAO_TOKEN}"

export BAO_ADDR="$OPENBAO_ADDR"
export BAO_TOKEN

read -rsp "Discord bot token: " DISCORD_TOKEN
echo
read -rp "Discord application id (optional): " DISCORD_APP_ID
read -rp "pyLoad base URL [http://127.0.0.1:8000]: " PYLOAD_URL
PYLOAD_URL="${PYLOAD_URL:-http://127.0.0.1:8000}"
read -rp "pyLoad maya-agent username [maya-agent]: " PYLOAD_USER
PYLOAD_USER="${PYLOAD_USER:-maya-agent}"
read -rsp "pyLoad maya-agent password: " PYLOAD_PASS
echo

bao kv put secret/maya/discord \
  token="$DISCORD_TOKEN" \
  application_id="${DISCORD_APP_ID:-}"

bao kv put secret/pyload/maya-agent \
  base_url="$PYLOAD_URL" \
  username="$PYLOAD_USER" \
  password="$PYLOAD_PASS"

echo "Secrets seeded. Verify with:"
echo "  bao kv get secret/maya/discord"
echo "  bao kv get secret/pyload/maya-agent"
