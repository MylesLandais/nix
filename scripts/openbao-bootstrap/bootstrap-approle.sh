#!/usr/bin/env bash
# Create maya-agent AppRole and policy.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${OPENBAO_ADDR:=http://127.0.0.1:8200}"
: "${OPENBAO_TOKEN:?Set OPENBAO_TOKEN (root or admin token)}"

export BAO_ADDR="$OPENBAO_ADDR"
export BAO_TOKEN

echo "Writing maya-agent policy ..."
bao policy write maya-agent "$SCRIPT_DIR/policies/maya-agent.hcl"

echo "Enabling approle auth ..."
bao auth enable approle 2>/dev/null || echo "approle already enabled"

echo "Creating maya-agent role ..."
bao write auth/approle/role/maya-agent \
  token_policies="maya-agent" \
  token_ttl=1h \
  token_max_ttl=4h \
  secret_id_ttl=0

ROLE_ID=$(bao read -field=role_id auth/approle/role/maya-agent/role-id)
SECRET_ID=$(bao write -field=secret_id -f auth/approle/role/maya-agent/secret-id)

echo ""
echo "=== maya-agent AppRole ==="
echo "OPENBAO_ROLE_ID=$ROLE_ID"
echo "OPENBAO_SECRET_ID=$SECRET_ID"
echo ""
echo "Store role_id in Nix: services.infra.mayaWorker.openbaoRoleId"
echo "Encrypt secret_id: agenix -e secrets/maya-approle-secret-id.age"
echo "  echo -n '$SECRET_ID' | agenix -e secrets/maya-approle-secret-id.age"
