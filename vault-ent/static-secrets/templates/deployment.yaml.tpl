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
      serviceAccountName: static-app-sa
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
            # passwords are masked so pod logs (and CI output) never show the value
            mask() { if [ -n "$1" ]; then echo "<${#1} chars, hidden>"; else echo "<empty>"; fi; }
            while true; do
              echo "=== Static Secrets from ENV ==="
              echo "Username: $USERNAME"
              echo "Password: $(mask "$PASSWORD")"
              echo ""
              echo "=== Static Secrets from file ==="
              echo "Username: $(cat /secrets/static/username 2>/dev/null)" || echo "username file not found"
              echo "Password: $(mask "$(cat /secrets/static/password 2>/dev/null)")"
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
