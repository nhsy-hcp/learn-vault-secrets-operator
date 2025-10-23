apiVersion: apps/v1
kind: Deployment
metadata:
  name: static-app
  namespace: ${APP_NAME}
  labels:
    app: static-app
spec:
  replicas: 1
  strategy:
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels:
      app: static-app
  template:
    metadata:
      labels:
        app: static-app
    spec:
      serviceAccountName: shared-app-sa
      volumes:
        - name: static-secrets
          secret:
            secretName: "secretkv"
      containers:
        - name: example
          image: alpine:latest
          command: ["/bin/sh", "-c"]
          args:
          - |
            while true; do
              echo "=== Static Secrets from ENV ==="
              echo "Username: $USERNAME"
              echo "Password: $PASSWORD"
              echo ""
              echo "=== Static Secrets from file ==="
              echo "Username: $(cat /secrets/static/username 2>/dev/null)" || echo "username file not found"
              echo "Password: $(cat /secrets/static/password 2>/dev/null)" || echo "password file not found"
              echo ""
              echo "=== All mounted secrets in /secrets/static ==="
              echo ""
              ls -la /secrets/static/
              echo ""
              echo "Waiting 10 minutes before next check... ($(date))"
              echo ""
              sleep 600
            done
          env:
            - name: USERNAME
              valueFrom:
                secretKeyRef:
                  name: "secretkv"
                  key: username
            - name: PASSWORD
              valueFrom:
                secretKeyRef:
                  name: "secretkv"
                  key: password
          volumeMounts:
            - name: static-secrets
              mountPath: /secrets/static
              readOnly: true
