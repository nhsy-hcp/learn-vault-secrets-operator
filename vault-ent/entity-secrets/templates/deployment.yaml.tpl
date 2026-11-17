apiVersion: apps/v1
kind: Deployment
metadata:
  name: entity-app
  namespace: ${APP_NAME}
  labels:
    app: entity-app
spec:
  replicas: 1
  strategy:
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels:
      app: entity-app
  template:
    metadata:
      labels:
        app: entity-app
    spec:
      serviceAccountName: ${APP_NAME}-sa
      volumes:
        - name: entity-secrets
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
              echo "=== Entity Secrets from ENV ==="
              echo "Team: $TEAM"
              echo "Username: $USERNAME"
              echo "Password: $(mask "$PASSWORD")"
              echo ""
              echo "=== Entity Secrets from file ==="
              echo "Username: $(cat /secrets/entity/username 2>/dev/null)" || echo "username file not found"
              echo "Password: $(mask "$(cat /secrets/entity/password 2>/dev/null)")"
              echo ""
              echo "=== All mounted secrets in /secrets/entity ==="
              echo ""
              ls -la /secrets/entity/
              echo ""
              echo "Waiting 10 minutes before next check... ($(date))"
              echo ""
              sleep 600
            done
          env:
            - name: TEAM
              valueFrom:
                secretKeyRef:
                  name: "secretkv"
                  key: team
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
            - name: entity-secrets
              mountPath: /secrets/entity
              readOnly: true
