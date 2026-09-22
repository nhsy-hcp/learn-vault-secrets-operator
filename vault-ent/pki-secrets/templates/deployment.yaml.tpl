apiVersion: apps/v1
kind: Deployment
metadata:
  name: pki-app
  namespace: ${APP_NAME}
  labels:
    app: pki-app
spec:
  replicas: 1
  strategy:
    rollingUpdate:
      maxUnavailable: 1
  selector:
    matchLabels:
      app: pki-app
  template:
    metadata:
      labels:
        app: pki-app
    spec:
      serviceAccountName: pki-app-sa
      volumes:
        - name: pki-app-certs
          secret:
            secretName: "pki-app-tls"
      containers:
        - name: example
          image: alpine:3.22
          command: ["/bin/sh", "-c"]
          args:
            - |
              apk add --no-cache openssl
              echo ""
              while true; do
                echo "=== Namespace: ${APP_NAME} ==="
                echo ""
                echo "=== Certificate issued by the SHARED pki/roles/pki-app ==="
                if [ -f /etc/tls/tls.crt ]; then
                  openssl x509 -in /etc/tls/tls.crt -noout \
                    -subject -issuer -enddate -ext subjectAltName
                else
                  echo "certificate not yet available, waiting..."
                fi
                echo ""
                echo "=== All mounted PKI certs in /etc/tls ==="
                ls -la /etc/tls/
                echo ""
                echo "Waiting 10 minutes before next check... ($(date))"
                echo ""
                sleep 600
              done
          volumeMounts:
            - name: pki-app-certs
              mountPath: /etc/tls
              readOnly: true
