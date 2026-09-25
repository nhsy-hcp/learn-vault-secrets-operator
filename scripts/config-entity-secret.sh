#!/bin/bash
# Pre-create Vault identity entities carrying application/team/business_unit metadata and bind each
# app's JWT entity alias (its service account name, <app>-sa) to them. Safe to re-run.
#
# Usage: VAULT_TOKEN=... scripts/config-entity-secret.sh [apps.json]
set -euo pipefail

APPS_FILE="${1:-vault-ent/entity-secrets/apps.json}"
AUTH_MOUNT="k8s-auth-mount"

: "${VAULT_TOKEN:?VAULT_TOKEN must be set}"

vault_cmd() {
  kubectl exec vault-0 -n vault -- env VAULT_TOKEN="${VAULT_TOKEN}" VAULT_NAMESPACE=tn001 vault "$@"
}

accessor=$(vault_cmd auth list -format=json | jq -r --arg m "${AUTH_MOUNT}/" '.[$m].accessor // empty')
if [ -z "${accessor}" ]; then
  echo "Auth mount ${AUTH_MOUNT} not found in tn001 - run 'task config:static-secret' first" >&2
  exit 1
fi
echo "Using ${AUTH_MOUNT} accessor ${accessor}"

while read -r name application_name team business_unit; do
  # Matches the role's user_claim, so each app needs a unique service account name
  alias_name="${name}-sa"
  echo "=== ${name} (application_name=${application_name}, team=${team}, business_unit=${business_unit}) ==="

  # Create or update the entity by name; metadata is replaced on every run
  vault_cmd write identity/entity/name/"${name}" \
    metadata="application_name=${application_name}" \
    metadata="team=${team}" \
    metadata="business_unit=${business_unit}" \
    metadata="namespace=${name}" >/dev/null
  entity_id=$(vault_cmd read -format=json identity/entity/name/"${name}" | jq -r '.data.id')

  # Returns nothing when no entity holds this alias yet
  lookup=$(vault_cmd write -format=json identity/lookup/entity \
    alias_name="${alias_name}" alias_mount_accessor="${accessor}" 2>/dev/null || true)
  current_entity=$(jq -r '.data.id // empty' <<<"${lookup}" 2>/dev/null || true)
  alias_id=$(jq -r --arg n "${alias_name}" --arg a "${accessor}" \
    '.data.aliases[]? | select(.name == $n and .mount_accessor == $a) | .id' <<<"${lookup}" 2>/dev/null || true)

  if [ -z "${alias_id}" ]; then
    vault_cmd write identity/entity-alias \
      name="${alias_name}" canonical_id="${entity_id}" mount_accessor="${accessor}" >/dev/null
    echo "Created alias ${alias_name} -> entity ${entity_id}"
  elif [ "${current_entity}" != "${entity_id}" ]; then
    # The app logged in before onboarding and Vault auto-created an entity; move the alias over
    vault_cmd write identity/entity-alias/id/"${alias_id}" \
      name="${alias_name}" canonical_id="${entity_id}" mount_accessor="${accessor}" >/dev/null
    echo "Re-pointed alias ${alias_name} from entity ${current_entity} to ${entity_id}"
  else
    echo "Alias ${alias_name} already bound to entity ${entity_id}"
  fi
done < <(jq -r '.[] | "\(.name) \(.application_name) \(.team) \(.business_unit)"' "${APPS_FILE}")
