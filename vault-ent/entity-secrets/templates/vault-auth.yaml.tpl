apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: entity-auth
  namespace: ${APP_NAME}
spec:
  method: jwt
  mount: k8s-auth-mount
  namespace: tn001
  jwt:
    role: entity-secret
    serviceAccount: ${APP_NAME}-sa
    audiences:
      - vault
