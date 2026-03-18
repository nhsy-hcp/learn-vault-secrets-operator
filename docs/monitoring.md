# Monitoring and Observability Guide

## Overview

This guide provides comprehensive monitoring and observability setup for HashiCorp Vault and Vault Secrets Operator (VSO) deployments on Kubernetes. It covers metrics collection, logging, alerting, and visualization strategies.

## Monitoring Architecture

### Components to Monitor

1. **Vault Server**
   - Health and seal status
   - Performance metrics
   - Audit logs
   - Storage backend metrics

2. **VSO Controller**
   - Secret sync operations
   - Authentication metrics
   - Cache performance
   - Error rates

3. **Kubernetes Infrastructure**
   - Pod health and restarts
   - Resource utilization
   - Network connectivity
   - Storage performance

4. **Applications**
   - Secret consumption
   - Authentication success/failure
   - Application health

## Metrics Collection

### Vault Metrics

#### Enable Prometheus Metrics

Vault exposes Prometheus metrics at `/v1/sys/metrics?format=prometheus`

**Configure Vault for Metrics:**

```hcl
# vault-config.hcl
telemetry {
  prometheus_retention_time = "30s"
  disable_hostname = true
}
```

**Expose Metrics via Service:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: vault-metrics
  namespace: vault
  labels:
    app.kubernetes.io/name: vault
spec:
  type: ClusterIP
  ports:
  - name: metrics
    port: 8200
    targetPort: 8200
  selector:
    app.kubernetes.io/name: vault
```

#### Key Vault Metrics

**Health Metrics:**
- `vault_core_unsealed` - Vault seal status (1 = unsealed, 0 = sealed)
- `vault_core_active` - Active node status
- `vault_core_standby` - Standby node status

**Performance Metrics:**
- `vault_runtime_alloc_bytes` - Memory allocated
- `vault_runtime_sys_bytes` - System memory
- `vault_runtime_num_goroutines` - Number of goroutines
- `vault_core_handle_request` - Request handling time
- `vault_core_handle_request_count` - Total requests

**Storage Metrics:**
- `vault_raft_apply` - Raft apply operations
- `vault_raft_commitTime` - Raft commit time
- `vault_raft_leader` - Leader status
- `vault_raft_peers` - Number of peers

**Authentication Metrics:**
- `vault_token_creation` - Token creation count
- `vault_token_creation_count` - Total tokens created
- `vault_expire_num_leases` - Active leases

**Audit Metrics:**
- `vault_audit_log_request` - Audit log requests
- `vault_audit_log_request_failure` - Audit log failures

### VSO Metrics

#### Enable VSO Metrics

VSO exposes Prometheus metrics on port 8080 at `/metrics`

**ServiceMonitor for VSO:**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: vault-secrets-operator
  namespace: vault-secrets-operator
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: vault-secrets-operator
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

#### Key VSO Metrics

**Secret Sync Metrics:**
- `controller_runtime_reconcile_total` - Total reconciliations
- `controller_runtime_reconcile_errors_total` - Reconciliation errors
- `controller_runtime_reconcile_time_seconds` - Reconciliation duration

**Cache Metrics:**
- `vso_client_cache_hits_total` - Cache hits
- `vso_client_cache_misses_total` - Cache misses
- `vso_client_cache_size` - Cache size

**Authentication Metrics:**
- `vso_vault_auth_success_total` - Successful authentications
- `vso_vault_auth_failure_total` - Failed authentications

### Kubernetes Metrics

#### Metrics Server

```bash
# Enable metrics-server (Minikube)
minikube addons enable metrics-server

# Install metrics-server (EKS/GKE)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

#### Key Kubernetes Metrics

**Pod Metrics:**
- CPU usage
- Memory usage
- Restart count
- Pod status

**Node Metrics:**
- CPU utilization
- Memory utilization
- Disk usage
- Network I/O

**PVC Metrics:**
- Storage usage
- IOPS
- Throughput

## Prometheus Setup

### Install Prometheus Operator

```bash
# Add Prometheus community Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install kube-prometheus-stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.enabled=true \
  --set grafana.adminPassword=admin
```

### Configure ServiceMonitors

**Vault ServiceMonitor:**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: vault
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames:
    - vault
  selector:
    matchLabels:
      app.kubernetes.io/name: vault
  endpoints:
  - port: http
    interval: 30s
    path: /v1/sys/metrics
    params:
      format: ['prometheus']
    scheme: http
```

**VSO ServiceMonitor:**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: vault-secrets-operator
  namespace: monitoring
spec:
  namespaceSelector:
    matchNames:
    - vault-secrets-operator
  selector:
    matchLabels:
      app.kubernetes.io/name: vault-secrets-operator
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### Prometheus Queries

**Vault Health:**
```promql
# Vault seal status
vault_core_unsealed

# Vault leader status
vault_raft_leader

# Request rate
rate(vault_core_handle_request_count[5m])

# Request latency (p95)
histogram_quantile(0.95, rate(vault_core_handle_request_bucket[5m]))
```

**VSO Performance:**
```promql
# Secret sync rate
rate(controller_runtime_reconcile_total{controller="vaultstaticsecret"}[5m])

# Error rate
rate(controller_runtime_reconcile_errors_total[5m])

# Cache hit rate
rate(vso_client_cache_hits_total[5m]) / (rate(vso_client_cache_hits_total[5m]) + rate(vso_client_cache_misses_total[5m]))
```

**Kubernetes Resources:**
```promql
# Pod CPU usage
sum(rate(container_cpu_usage_seconds_total{namespace="vault"}[5m])) by (pod)

# Pod memory usage
sum(container_memory_working_set_bytes{namespace="vault"}) by (pod)

# Pod restart count
kube_pod_container_status_restarts_total{namespace="vault"}
```

## Grafana Dashboards

### Access Grafana

```bash
# Port forward Grafana
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access at http://localhost:3000
# Default credentials: admin / admin (or password set during install)
```

### Import Dashboards

**Vault Dashboard:**

```json
{
  "dashboard": {
    "title": "Vault Monitoring",
    "panels": [
      {
        "title": "Vault Seal Status",
        "targets": [
          {
            "expr": "vault_core_unsealed"
          }
        ]
      },
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "rate(vault_core_handle_request_count[5m])"
          }
        ]
      },
      {
        "title": "Request Latency (p95)",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(vault_core_handle_request_bucket[5m]))"
          }
        ]
      },
      {
        "title": "Memory Usage",
        "targets": [
          {
            "expr": "vault_runtime_alloc_bytes"
          }
        ]
      },
      {
        "title": "Active Leases",
        "targets": [
          {
            "expr": "vault_expire_num_leases"
          }
        ]
      }
    ]
  }
}
```

**VSO Dashboard:**

```json
{
  "dashboard": {
    "title": "VSO Monitoring",
    "panels": [
      {
        "title": "Secret Sync Rate",
        "targets": [
          {
            "expr": "rate(controller_runtime_reconcile_total[5m])"
          }
        ]
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "rate(controller_runtime_reconcile_errors_total[5m])"
          }
        ]
      },
      {
        "title": "Cache Hit Rate",
        "targets": [
          {
            "expr": "rate(vso_client_cache_hits_total[5m]) / (rate(vso_client_cache_hits_total[5m]) + rate(vso_client_cache_misses_total[5m]))"
          }
        ]
      },
      {
        "title": "Authentication Success Rate",
        "targets": [
          {
            "expr": "rate(vso_vault_auth_success_total[5m])"
          }
        ]
      }
    ]
  }
}
```

### Pre-built Dashboards

**Import from Grafana.com:**
- Vault Dashboard: ID 12904
- Kubernetes Cluster Monitoring: ID 7249
- Kubernetes Pod Monitoring: ID 6417

```bash
# Import via Grafana UI
# Dashboards -> Import -> Enter Dashboard ID
```

## Logging

### Centralized Logging Architecture

```
┌─────────────┐
│   Pods      │
│  (stdout)   │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Fluentd/   │
│  Fluent Bit │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Elasticsearch│
│  or Loki    │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│   Kibana/   │
│   Grafana   │
└─────────────┘
```

### Loki Stack Setup

```bash
# Install Loki stack (Loki + Promtail + Grafana)
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=true \
  --set prometheus.enabled=true \
  --set promtail.enabled=true
```

### Log Collection

**Promtail Configuration:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: monitoring
data:
  promtail.yaml: |
    server:
      http_listen_port: 9080
      grpc_listen_port: 0

    positions:
      filename: /tmp/positions.yaml

    clients:
      - url: http://loki:3100/loki/api/v1/push

    scrape_configs:
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_app_kubernetes_io_name]
            target_label: app
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            target_label: pod
```

### Log Queries

**Vault Logs:**
```logql
# All Vault logs
{namespace="vault", app="vault"}

# Vault errors
{namespace="vault", app="vault"} |= "error"

# Authentication failures
{namespace="vault", app="vault"} |= "permission denied"

# Audit logs
{namespace="vault", app="vault"} |= "audit"
```

**VSO Logs:**
```logql
# All VSO logs
{namespace="vault-secrets-operator"}

# VSO errors
{namespace="vault-secrets-operator"} |= "error"

# Secret sync events
{namespace="vault-secrets-operator"} |= "reconcile"

# Authentication events
{namespace="vault-secrets-operator"} |= "auth"
```

**Application Logs:**
```logql
# Static app logs
{namespace=~"static-app-.*"}

# Dynamic app logs
{namespace="dynamic-app"}

# CSI app logs
{namespace="csi-app"}
```

### Vault Audit Logs

**Enable File Audit Device:**

```bash
# Enable audit logging
kubectl exec -n vault vault-0 -- vault audit enable file file_path=/vault/logs/audit.log

# View audit logs
kubectl exec -n vault vault-0 -- tail -f /vault/logs/audit.log
```

**Audit Log Format:**

```json
{
  "time": "2026-03-18T09:00:00.000000Z",
  "type": "request",
  "auth": {
    "client_token": "hmac-sha256:...",
    "accessor": "hmac-sha256:...",
    "display_name": "kubernetes-static-app-sa",
    "policies": ["default", "static-secret"]
  },
  "request": {
    "id": "...",
    "operation": "read",
    "path": "tn001/kvv2/data/webapp/config",
    "namespace": {
      "id": "tn001"
    }
  }
}
```

## Alerting

### AlertManager Setup

AlertManager is included with kube-prometheus-stack.

**Access AlertManager:**

```bash
# Port forward AlertManager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093

# Access at http://localhost:9093
```

### Alert Rules

**Vault Alerts:**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: vault-alerts
  namespace: monitoring
spec:
  groups:
  - name: vault
    interval: 30s
    rules:
    - alert: VaultSealed
      expr: vault_core_unsealed == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Vault is sealed"
        description: "Vault instance {{ $labels.instance }} is sealed"

    - alert: VaultDown
      expr: up{job="vault"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Vault is down"
        description: "Vault instance {{ $labels.instance }} is down"

    - alert: VaultHighRequestLatency
      expr: histogram_quantile(0.95, rate(vault_core_handle_request_bucket[5m])) > 1
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Vault high request latency"
        description: "Vault p95 latency is {{ $value }}s"

    - alert: VaultHighMemoryUsage
      expr: vault_runtime_alloc_bytes > 1073741824
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Vault high memory usage"
        description: "Vault memory usage is {{ $value | humanize }}B"

    - alert: VaultLeadershipLost
      expr: changes(vault_raft_leader[5m]) > 0
      for: 1m
      labels:
        severity: warning
      annotations:
        summary: "Vault leadership changed"
        description: "Vault leadership has changed"

    - alert: VaultAuditLogFailure
      expr: rate(vault_audit_log_request_failure[5m]) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Vault audit log failures"
        description: "Vault audit logging is failing"
```

**VSO Alerts:**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: vso-alerts
  namespace: monitoring
spec:
  groups:
  - name: vso
    interval: 30s
    rules:
    - alert: VSODown
      expr: up{job="vault-secrets-operator"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "VSO is down"
        description: "VSO controller is not responding"

    - alert: VSOHighErrorRate
      expr: rate(controller_runtime_reconcile_errors_total[5m]) > 0.1
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "VSO high error rate"
        description: "VSO error rate is {{ $value | humanizePercentage }}"

    - alert: VSOSecretSyncFailure
      expr: increase(controller_runtime_reconcile_errors_total{controller="vaultstaticsecret"}[5m]) > 5
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "VSO secret sync failures"
        description: "Multiple secret sync failures detected"

    - alert: VSOAuthenticationFailure
      expr: rate(vso_vault_auth_failure_total[5m]) > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "VSO authentication failures"
        description: "VSO is experiencing authentication failures"

    - alert: VSOLowCacheHitRate
      expr: rate(vso_client_cache_hits_total[5m]) / (rate(vso_client_cache_hits_total[5m]) + rate(vso_client_cache_misses_total[5m])) < 0.5
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "VSO low cache hit rate"
        description: "VSO cache hit rate is {{ $value | humanizePercentage }}"
```

**Kubernetes Alerts:**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: kubernetes-alerts
  namespace: monitoring
spec:
  groups:
  - name: kubernetes
    interval: 30s
    rules:
    - alert: PodCrashLooping
      expr: rate(kube_pod_container_status_restarts_total{namespace=~"vault|vault-secrets-operator|static-app-.*|dynamic-app|csi-app"}[15m]) > 0
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "Pod is crash looping"
        description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is crash looping"

    - alert: PodNotReady
      expr: kube_pod_status_phase{namespace=~"vault|vault-secrets-operator|static-app-.*|dynamic-app|csi-app", phase!="Running"} == 1
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "Pod not ready"
        description: "Pod {{ $labels.namespace }}/{{ $labels.pod }} is not ready"

    - alert: PVCStorageFull
      expr: kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes > 0.9
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "PVC storage almost full"
        description: "PVC {{ $labels.persistentvolumeclaim }} is {{ $value | humanizePercentage }} full"

    - alert: HighPodMemoryUsage
      expr: sum(container_memory_working_set_bytes{namespace="vault"}) by (pod) / sum(container_spec_memory_limit_bytes{namespace="vault"}) by (pod) > 0.9
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "High pod memory usage"
        description: "Pod {{ $labels.pod }} memory usage is {{ $value | humanizePercentage }}"
```

### Notification Channels

**Slack Integration:**

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-config
  namespace: monitoring
stringData:
  alertmanager.yaml: |
    global:
      resolve_timeout: 5m
      slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'

    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 12h
      receiver: 'slack-notifications'
      routes:
      - match:
          severity: critical
        receiver: 'slack-critical'

    receivers:
    - name: 'slack-notifications'
      slack_configs:
      - channel: '#vault-alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

    - name: 'slack-critical'
      slack_configs:
      - channel: '#vault-critical'
        title: 'CRITICAL: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
```

**Email Integration:**

```yaml
receivers:
- name: 'email-notifications'
  email_configs:
  - to: 'ops-team@example.com'
    from: 'alertmanager@example.com'
    smarthost: 'smtp.example.com:587'
    auth_username: 'alertmanager@example.com'
    auth_password: 'password'
    headers:
      Subject: 'Vault Alert: {{ .GroupLabels.alertname }}'
```

## Health Checks

### Vault Health Endpoint

```bash
# Check Vault health
curl http://vault.vault.svc.cluster.local:8200/v1/sys/health

# Response codes:
# 200 - Initialized, unsealed, and active
# 429 - Unsealed and standby
# 472 - Disaster recovery mode replication secondary and active
# 473 - Performance standby
# 501 - Not initialized
# 503 - Sealed
```

### Kubernetes Liveness and Readiness Probes

**Vault Probes:**

```yaml
livenessProbe:
  httpGet:
    path: /v1/sys/health?standbyok=true
    port: 8200
  initialDelaySeconds: 60
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3

readinessProbe:
  httpGet:
    path: /v1/sys/health?standbyok=true&perfstandbyok=true
    port: 8200
  initialDelaySeconds: 5
  periodSeconds: 5
  timeoutSeconds: 3
  successThreshold: 1
  failureThreshold: 3
```

**VSO Probes:**

```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8081
  initialDelaySeconds: 15
  periodSeconds: 20

readinessProbe:
  httpGet:
    path: /readyz
    port: 8081
  initialDelaySeconds: 5
  periodSeconds: 10
```

## Tracing

### Distributed Tracing with Jaeger

```bash
# Install Jaeger operator
kubectl create namespace observability
kubectl apply -f https://github.com/jaegertracing/jaeger-operator/releases/download/v1.42.0/jaeger-operator.yaml -n observability

# Deploy Jaeger instance
cat <<EOF | kubectl apply -f -
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger
  namespace: observability
spec:
  strategy: allInOne
  allInOne:
    image: jaegertracing/all-in-one:latest
    options:
      log-level: debug
  storage:
    type: memory
    options:
      memory:
        max-traces: 100000
  ingress:
    enabled: false
EOF

# Access Jaeger UI
kubectl port-forward -n observability svc/jaeger-query 16686:16686
# Open http://localhost:16686
```

## Monitoring Best Practices

### 1. Define SLIs and SLOs

**Service Level Indicators (SLIs):**
- Vault availability: % of time unsealed
- Secret sync success rate: % of successful syncs
- Request latency: p95 response time
- Error rate: % of failed requests

**Service Level Objectives (SLOs):**
- Vault availability: 99.9% uptime
- Secret sync success: 99.5% success rate
- Request latency: p95 < 500ms
- Error rate: < 0.1%

### 2. Alert Fatigue Prevention

- Set appropriate thresholds
- Use alert grouping
- Implement alert suppression during maintenance
- Regular alert review and tuning

### 3. Observability Maturity

**Level 1: Basic**
- Pod health monitoring
- Basic metrics collection
- Manual log review

**Level 2: Intermediate**
- Automated alerting
- Centralized logging
- Dashboard visualization

**Level 3: Advanced**
- Distributed tracing
- Anomaly detection
- Predictive alerting
- Full observability stack

### 4. Regular Review

- Weekly: Review alerts and incidents
- Monthly: Analyze trends and patterns
- Quarterly: Update SLOs and dashboards
- Annually: Comprehensive observability audit

## Troubleshooting Monitoring Issues

### Metrics Not Appearing

```bash
# Check ServiceMonitor
kubectl get servicemonitor -n monitoring

# Check Prometheus targets
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090/targets

# Check pod labels match ServiceMonitor selector
kubectl get pods -n vault --show-labels
```

### Alerts Not Firing

```bash
# Check PrometheusRule
kubectl get prometheusrule -n monitoring

# Check AlertManager
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
# Open http://localhost:9093

# Check alert rule syntax
kubectl logs -n monitoring prometheus-kube-prometheus-operator-xxxxx
```

### Logs Not Collected

```bash
# Check Promtail pods
kubectl get pods -n monitoring -l app=promtail

# Check Promtail logs
kubectl logs -n monitoring -l app=promtail

# Check Loki
kubectl get pods -n monitoring -l app=loki
kubectl logs -n monitoring -l app=loki
```

## Additional Resources

- [Vault Telemetry](https://developer.hashicorp.com/vault/docs/configuration/telemetry)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Jaeger Tracing](https://www.jaegertracing.io/docs/)
