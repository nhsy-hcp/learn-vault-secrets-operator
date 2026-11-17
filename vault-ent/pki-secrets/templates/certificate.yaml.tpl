apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: pki-app-cert
  namespace: ${APP_NAME}
spec:
  # cert-manager writes the signed certificate and key here
  secretName: pki-app-tls

  # VSO external issuer backed by the tn001 pki mount
  issuerRef:
    group: secrets.hashicorp.com
    kind: VaultClusterIssuer
    name: vault-pki

  # quoted so a wildcard name is not parsed as a YAML alias
  commonName: "${COMMON_NAME}"
  dnsNames:
    - "${COMMON_NAME}"
    - "${ALT_NAME}"
    - "${LB_NAME}"

  duration: 1h
  # renew when within this window of expiry
  renewBefore: 15m
  privateKey:
    algorithm: RSA
    size: 2048
    rotationPolicy: Always
