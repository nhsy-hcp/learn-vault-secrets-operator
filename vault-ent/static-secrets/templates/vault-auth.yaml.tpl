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
    role: static-secret
    serviceAccount: static-app-sa
    audiences:
      - vault
