apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: pki-auth
  namespace: ${APP_NAME}
spec:
  method: kubernetes
  mount: kubernetes-auth-mount
  namespace: tn001
  kubernetes:
    role: pki-secret
    serviceAccount: ${APP_NAME}-sa
    audiences:
      - vault
