apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: vault-kv-app
  namespace: ${APP_NAME}
spec:
  type: kv-v2

  # vault namespace
  namespace: tn001

  # mount path
  mount: kvv2

  # team path - the entity-secret policy only allows the team in the entity's metadata
  path: teams/${TEAM}/config

  # dest k8s secret
  destination:
    name: secretkv
    create: true

  # static secret refresh interval
  refreshAfter: 1h

  # Name of the CRD to authenticate to Vault
  vaultAuthRef: entity-auth
  syncConfig:
    instantUpdates: true
