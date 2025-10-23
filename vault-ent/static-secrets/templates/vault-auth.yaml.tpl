apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: static-auth
  namespace: ${APP_NAME}
spec:
  method: jwt
  mount: k8s-auth-mount
  namespace: tn001
  jwt:
    role: shared-secret
    serviceAccount: shared-app-sa
    audiences:
      - vault
