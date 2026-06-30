#!/usr/bin/env bash
# Enable KV v2 and write placeholder secret paths.
set -euo pipefail

: "${OPENBAO_ADDR:=http://127.0.0.1:8200}"
: "${OPENBAO_TOKEN:?Set OPENBAO_TOKEN (root or admin token)}"

export BAO_ADDR="$OPENBAO_ADDR"
export BAO_TOKEN

echo "Enabling KV v2 at secret/ ..."
bao secrets enable -path=secret kv-v2 2>/dev/null || echo "secret/ already enabled"

echo "Writing placeholder secrets (replace via seed-secrets.sh) ..."
bao kv put secret/maya/discord token="REPLACE_ME" application_id=""
bao kv put secret/pyload/maya-agent \
  base_url="http://127.0.0.1:8000" \
  username="maya-agent" \
  password="REPLACE_ME"

echo "KV bootstrap complete."
