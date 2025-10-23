apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: vault-kv-app
  namespace: ${APP_NAME}
spec:
  # vaultConnectionRef: static-app/static-default
  type: kv-v2

  # vault namespace
  namespace: tn001

  # mount path
  mount: kvv2

  # path of the secret
  path: webapp/config

  # dest k8s secret
  destination:
    name: secretkv
    create: true

  # static secret refresh interval
  refreshAfter: 1h

  # Name of the CRD to authenticate to Vault
  vaultAuthRef: static-auth
  syncConfig:
    instantUpdates: true
