apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultPKISecret
metadata:
  name: pki-app-cert
  namespace: ${APP_NAME}
spec:
  # Name of the CRD to authenticate to Vault
  vaultAuthRef: pki-auth

  # vault namespace
  namespace: tn001

  # mount path
  mount: pki

  # per-app pki role, matching the service account pki_role annotation
  role: ${APP_NAME}

  # quoted so a wildcard name is not parsed as a YAML alias
  commonName: "${COMMON_NAME}"
  altNames:
    - "${ALT_NAME}"
    - "${LB_NAME}"
  format: pem

  # renew when within this window of expiry
  expiryOffset: 15m
  clear: true

  # dest k8s secret
  destination:
    create: true
    name: pki-app-tls
    type: kubernetes.io/tls
    transformation:
      excludeRaw: true

  rolloutRestartTargets:
    - kind: Deployment
      name: pki-app
