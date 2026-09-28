#!/bin/bash
# Configure the tn001 kubernetes auth mount (service account annotations become alias metadata),
# the templated pki-secret policy and role, and one PKI issuing role per app. Safe to re-run.
#
# Usage: VAULT_TOKEN=... KUBE_HOST=... scripts/config-pki-secret.sh [app_count] [max_ttl]
set -euo pipefail

APP_COUNT="${1:-3}"
MAX_TTL="${2:-4h}"
AUTH_MOUNT="kubernetes-auth-mount"

: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"
: "${KUBE_HOST:?KUBE_HOST must be set}"

vault_cmd() {
  kubectl exec -i vault-0 -n vault -- env VAULT_TOKEN="${VAULT_TOKEN}" VAULT_NAMESPACE=tn001 vault "$@"
}

vault_cmd auth enable -path "${AUTH_MOUNT}" kubernetes 2>/dev/null || echo "${AUTH_MOUNT} already enabled"

# Vault reads service accounts with this token, so it needs the vault-sa-reader ClusterRole
reviewer_jwt=$(kubectl get secret vault-token-secret -n vault -o json | jq -r .data.token | base64 --decode)
vault_cmd write "auth/${AUTH_MOUNT}/config" \
  kubernetes_host="https://${KUBE_HOST}:443" \
  token_reviewer_jwt="${reviewer_jwt}" \
  use_annotations_as_alias_metadata=true >/dev/null

accessor=$(vault_cmd auth list -format=json | jq -r --arg m "${AUTH_MOUNT}/" '.[$m].accessor // empty')
if [ -z "${accessor}" ]; then
  echo "Auth mount ${AUTH_MOUNT} not found in tn001" >&2
  exit 1
fi
echo "Using ${AUTH_MOUNT} accessor ${accessor}"

# Policy templates reference alias metadata by mount accessor, which is only known after enabling
sed "s/__ACCESSOR__/${accessor}/g" vault-ent/pki-secrets/pki-secret.hcl | vault_cmd policy write pki-secret -
vault_cmd write "auth/${AUTH_MOUNT}/role/pki-secret" - < vault-ent/pki-secrets/pki-secret-role.json

# allowed_domains limits each role to its own app; "svc" covers the short in-cluster name
for i in $(seq 1 "${APP_COUNT}"); do
  app="pki-app-${i}"
  vault_cmd write "pki/roles/${app}" \
    allowed_domains="${app}.svc.cluster.local,${app}.svc,${app}.example.com" \
    allow_subdomains=true \
    allow_bare_domains=true \
    allow_wildcard_certificates=true \
    allow_ip_sans=false \
    allow_localhost=false \
    key_type=rsa \
    key_bits=2048 \
    ttl=1h \
    max_ttl="${MAX_TTL}" >/dev/null
  echo "Wrote pki/roles/${app}"
done
