# Backup and Disaster Recovery Guide

## Overview

This guide provides comprehensive backup and disaster recovery procedures for HashiCorp Vault and Vault Secrets Operator (VSO) deployments on Kubernetes. It covers backup strategies, recovery procedures, and business continuity planning.

## Backup Strategy

### What to Backup

#### Critical Components

1. **Vault Data**
   - Raft storage backend data
   - Vault configuration
   - Unseal keys and root token
   - Audit logs

2. **Kubernetes Resources**
   - Vault manifests and Helm values
   - VSO manifests and Helm values
   - Application manifests (VaultAuth, VaultStaticSecret, VaultDynamicSecret)
   - Service accounts and RBAC configurations

3. **Vault Configuration**
   - Policies
   - Auth method configurations
   - Secret engine configurations
   - Roles and role bindings

4. **Application Data**
   - PostgreSQL database (for dynamic secrets demo)
   - Application-specific data

### Backup Frequency

| Component | Frequency | Retention | Priority |
|-----------|-----------|-----------|----------|
| Vault Raft Snapshots | Daily | 30 days | Critical |
| Vault Configuration | On change | 90 days | High |
| Kubernetes Manifests | On change | Indefinite (Git) | High |
| Audit Logs | Daily | 90 days | Medium |
| Application Data | Daily | 7 days | Low |

## Vault Backup Procedures

### Automated Raft Snapshots

#### Create Backup Script

```bash
#!/bin/bash
# save as scripts/backup-vault.sh

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-./backups}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/vault-snapshot-${TIMESTAMP}.snap"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# Take Raft snapshot
echo "Taking Vault snapshot..."
kubectl exec -n vault vault-0 -- vault operator raft snapshot save /tmp/backup.snap

# Copy snapshot from pod
echo "Copying snapshot from pod..."
kubectl cp vault/vault-0:/tmp/backup.snap "${BACKUP_FILE}"

# Verify snapshot
echo "Verifying snapshot..."
if [ -f "${BACKUP_FILE}" ]; then
    SIZE=$(stat -f%z "${BACKUP_FILE}" 2>/dev/null || stat -c%s "${BACKUP_FILE}" 2>/dev/null)
    if [ "${SIZE}" -gt 0 ]; then
        echo "Backup successful: ${BACKUP_FILE} (${SIZE} bytes)"
    else
        echo "Error: Backup file is empty"
        exit 1
    fi
else
    echo "Error: Backup file not found"
    exit 1
fi

# Cleanup old backups (keep last 30 days)
echo "Cleaning up old backups..."
find "${BACKUP_DIR}" -name "vault-snapshot-*.snap" -mtime +30 -delete

echo "Backup complete!"
```

#### Schedule Automated Backups

**Using Kubernetes CronJob:**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: vault-backup
  namespace: vault
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: vault
          containers:
          - name: backup
            image: hashicorp/vault:1.15.0
            command:
            - /bin/sh
            - -c
            - |
              vault operator raft snapshot save /backup/vault-snapshot-$(date +%Y%m%d-%H%M%S).snap
              find /backup -name "vault-snapshot-*.snap" -mtime +30 -delete
            env:
            - name: VAULT_ADDR
              value: "http://vault:8200"
            - name: VAULT_TOKEN
              valueFrom:
                secretKeyRef:
                  name: vault-token
                  key: token
            volumeMounts:
            - name: backup
              mountPath: /backup
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: vault-backup-pvc
          restartPolicy: OnFailure
```

**Using Cron (Local/VM):**

```bash
# Add to crontab
crontab -e

# Add this line for daily backups at 2 AM
0 2 * * * /path/to/scripts/backup-vault.sh >> /var/log/vault-backup.log 2>&1
```

### Manual Backup

```bash
# Take immediate snapshot
kubectl exec -n vault vault-0 -- vault operator raft snapshot save /tmp/manual-backup.snap

# Copy to local machine
kubectl cp vault/vault-0:/tmp/manual-backup.snap ./vault-backup-$(date +%Y%m%d-%H%M%S).snap

# Verify backup
ls -lh vault-backup-*.snap
```

### Backup Vault Configuration

#### Export Policies

```bash
#!/bin/bash
# save as scripts/backup-vault-config.sh

BACKUP_DIR="./backups/vault-config-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${BACKUP_DIR}"

# Export policies from tn001 namespace
echo "Exporting policies..."
for policy in $(kubectl exec -n vault vault-0 -- vault policy list -namespace=tn001 | grep -v "^default$" | grep -v "^root$"); do
    echo "Exporting policy: ${policy}"
    kubectl exec -n vault vault-0 -- vault policy read -namespace=tn001 "${policy}" > "${BACKUP_DIR}/policy-${policy}.hcl"
done

# Export auth method configurations
echo "Exporting auth methods..."
kubectl exec -n vault vault-0 -- vault read -namespace=tn001 -format=json auth/k8s-auth-mount/config > "${BACKUP_DIR}/auth-k8s-config.json"

# Export roles
echo "Exporting roles..."
for role in static-secret dynamic-secret csi-secret; do
    kubectl exec -n vault vault-0 -- vault read -namespace=tn001 -format=json auth/k8s-auth-mount/role/${role} > "${BACKUP_DIR}/role-${role}.json"
done

# Export secret engine configurations
echo "Exporting secret engines..."
kubectl exec -n vault vault-0 -- vault read -namespace=tn001 -format=json db/config/postgres > "${BACKUP_DIR}/db-config-postgres.json" || true
kubectl exec -n vault vault-0 -- vault read -namespace=tn001 -format=json db/roles/dev-postgres > "${BACKUP_DIR}/db-role-dev-postgres.json" || true
kubectl exec -n vault vault-0 -- vault read -namespace=tn001 -format=json pki/roles/example-dot-com > "${BACKUP_DIR}/pki-role-example-dot-com.json" || true

echo "Configuration backup complete: ${BACKUP_DIR}"
```

### Backup Unseal Keys and Root Token

**CRITICAL: Store securely and separately from Vault data**

```bash
# Backup vault-init.json (contains unseal keys and root token)
cp vault-init.json ./backups/vault-init-$(date +%Y%m%d-%H%M%S).json

# Encrypt backup (recommended)
gpg --encrypt --recipient your-email@example.com vault-init.json

# Store in secure location:
# - Password manager (1Password, LastPass, etc.)
# - Hardware security module (HSM)
# - Cloud secret manager (AWS Secrets Manager, GCP Secret Manager)
# - Offline encrypted storage
```

### Backup to Cloud Storage

#### AWS S3

```bash
#!/bin/bash
# Upload to S3

BACKUP_FILE="vault-snapshot-$(date +%Y%m%d-%H%M%S).snap"
S3_BUCKET="your-vault-backups"

# Take snapshot
kubectl exec -n vault vault-0 -- vault operator raft snapshot save /tmp/backup.snap
kubectl cp vault/vault-0:/tmp/backup.snap "./${BACKUP_FILE}"

# Upload to S3
aws s3 cp "${BACKUP_FILE}" "s3://${S3_BUCKET}/vault-snapshots/${BACKUP_FILE}"

# Enable versioning and lifecycle policies
aws s3api put-bucket-versioning --bucket "${S3_BUCKET}" --versioning-configuration Status=Enabled
```

#### Google Cloud Storage

```bash
#!/bin/bash
# Upload to GCS

BACKUP_FILE="vault-snapshot-$(date +%Y%m%d-%H%M%S).snap"
GCS_BUCKET="your-vault-backups"

# Take snapshot
kubectl exec -n vault vault-0 -- vault operator raft snapshot save /tmp/backup.snap
kubectl cp vault/vault-0:/tmp/backup.snap "./${BACKUP_FILE}"

# Upload to GCS
gsutil cp "${BACKUP_FILE}" "gs://${GCS_BUCKET}/vault-snapshots/${BACKUP_FILE}"

# Enable versioning
gsutil versioning set on "gs://${GCS_BUCKET}"
```

## Kubernetes Resources Backup

### Export All Manifests

```bash
#!/bin/bash
# save as scripts/backup-k8s-resources.sh

BACKUP_DIR="./backups/k8s-resources-$(date +%Y%m%d-%H%M%S)"
mkdir -p "${BACKUP_DIR}"

# Backup Vault namespace
echo "Backing up Vault namespace..."
kubectl get all,pvc,secret,configmap,serviceaccount,role,rolebinding -n vault -o yaml > "${BACKUP_DIR}/vault-namespace.yaml"

# Backup VSO namespace
echo "Backing up VSO namespace..."
kubectl get all,secret,configmap,serviceaccount,role,rolebinding -n vault-secrets-operator -o yaml > "${BACKUP_DIR}/vso-namespace.yaml"

# Backup application namespaces
for ns in static-app-1 static-app-2 static-app-3 dynamic-app csi-app; do
    echo "Backing up ${ns} namespace..."
    kubectl get all,vaultauth,vaultstaticsecret,vaultdynamicsecret,secretproviderclass,secret,configmap,serviceaccount -n ${ns} -o yaml > "${BACKUP_DIR}/${ns}-namespace.yaml"
done

# Backup cluster-wide resources
echo "Backing up cluster-wide resources..."
kubectl get clusterrole,clusterrolebinding -o yaml | grep -A 1000 "name: vault" > "${BACKUP_DIR}/cluster-resources.yaml"

# Backup CRDs
echo "Backing up CRDs..."
kubectl get crd -o yaml | grep -A 1000 "secrets.hashicorp.com" > "${BACKUP_DIR}/crds.yaml"

echo "Kubernetes resources backup complete: ${BACKUP_DIR}"
```

### Version Control (Recommended)

```bash
# Initialize Git repository for manifests
cd vault-ent/
git init
git add .
git commit -m "Initial commit of Vault manifests"

# Push to remote repository
git remote add origin https://github.com/your-org/vault-k8s-config.git
git push -u origin main

# Automate commits on changes
# Add to CI/CD pipeline or use GitOps tools (ArgoCD, Flux)
```

## Recovery Procedures

### Vault Cluster Recovery

#### Scenario 1: Single Pod Failure

**Symptoms:**
- One Vault pod is down
- Other pods are healthy
- Cluster is still operational

**Recovery:**

```bash
# Check pod status
kubectl get pods -n vault

# Delete failed pod (StatefulSet will recreate)
kubectl delete pod vault-0 -n vault

# Wait for pod to restart
kubectl wait --for=condition=ready pod vault-0 -n vault --timeout=300s

# Verify Vault status
kubectl exec -n vault vault-0 -- vault status

# Unseal if needed
kubectl exec -n vault vault-0 -- vault operator unseal <key1>
kubectl exec -n vault vault-0 -- vault operator unseal <key2>
kubectl exec -n vault vault-0 -- vault operator unseal <key3>
```

#### Scenario 2: Complete Vault Cluster Failure

**Symptoms:**
- All Vault pods are down
- PVCs may be intact or lost
- Need to restore from backup

**Recovery:**

```bash
# 1. Delete existing Vault installation
helm uninstall vault -n vault

# 2. Delete PVCs if corrupted
kubectl delete pvc -n vault --all

# 3. Reinstall Vault
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  -f vault-ent/vault-values.yaml

# 4. Wait for pod to be ready
kubectl wait --for=condition=ready pod vault-0 -n vault --timeout=300s

# 5. Initialize Vault (if starting fresh)
kubectl exec -n vault vault-0 -- vault operator init -format=json > vault-init-new.json

# 6. Unseal Vault
for key in $(jq -r '.unseal_keys_b64[]' vault-init-new.json | head -3); do
    kubectl exec -n vault vault-0 -- vault operator unseal $key
done

# 7. Restore from snapshot
BACKUP_FILE="vault-snapshot-20260318-020000.snap"
kubectl cp "${BACKUP_FILE}" vault/vault-0:/tmp/restore.snap
kubectl exec -n vault vault-0 -- vault operator raft snapshot restore -force /tmp/restore.snap

# 8. Restart Vault
kubectl delete pod vault-0 -n vault
kubectl wait --for=condition=ready pod vault-0 -n vault --timeout=300s

# 9. Unseal again
for key in $(jq -r '.unseal_keys_b64[]' vault-init.json | head -3); do
    kubectl exec -n vault vault-0 -- vault operator unseal $key
done

# 10. Verify data
kubectl exec -n vault vault-0 -- vault kv get -namespace=tn001 kvv2/webapp/config
```

#### Scenario 3: Vault Data Corruption

**Symptoms:**
- Vault is running but data is corrupted
- Secrets are missing or incorrect
- Need to restore from backup

**Recovery:**

```bash
# 1. Take current snapshot (for safety)
kubectl exec -n vault vault-0 -- vault operator raft snapshot save /tmp/pre-restore.snap
kubectl cp vault/vault-0:/tmp/pre-restore.snap ./vault-pre-restore-$(date +%Y%m%d-%H%M%S).snap

# 2. Restore from known good backup
BACKUP_FILE="vault-snapshot-20260318-020000.snap"
kubectl cp "${BACKUP_FILE}" vault/vault-0:/tmp/restore.snap
kubectl exec -n vault vault-0 -- vault operator raft snapshot restore -force /tmp/restore.snap

# 3. Restart Vault
kubectl delete pod vault-0 -n vault
kubectl wait --for=condition=ready pod vault-0 -n vault --timeout=300s

# 4. Unseal
for key in $(jq -r '.unseal_keys_b64[]' vault-init.json | head -3); do
    kubectl exec -n vault vault-0 -- vault operator unseal $key
done

# 5. Verify data integrity
kubectl exec -n vault vault-0 -- vault kv get -namespace=tn001 kvv2/webapp/config
kubectl exec -n vault vault-0 -- vault read -namespace=tn001 db/config/postgres
```

### VSO Recovery

#### Scenario 1: VSO Controller Failure

**Symptoms:**
- VSO controller pod is down
- Secrets not syncing
- VaultAuth resources show errors

**Recovery:**

```bash
# 1. Check VSO pod status
kubectl get pods -n vault-secrets-operator

# 2. Check logs for errors
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator

# 3. Restart VSO controller
kubectl rollout restart deployment -n vault-secrets-operator vault-secrets-operator-controller-manager

# 4. Wait for pod to be ready
kubectl wait --for=condition=ready pod -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator --timeout=300s

# 5. Verify secret sync resumes
kubectl get vaultstaticsecret -A
kubectl get secret secretkv -n static-app-1
```

#### Scenario 2: Complete VSO Reinstallation

**Symptoms:**
- VSO completely removed or corrupted
- Need to reinstall from scratch

**Recovery:**

```bash
# 1. Uninstall VSO
helm uninstall vault-secrets-operator -n vault-secrets-operator

# 2. Delete namespace
kubectl delete namespace vault-secrets-operator

# 3. Reinstall VSO
helm install vault-secrets-operator hashicorp/vault-secrets-operator \
  --namespace vault-secrets-operator \
  --create-namespace \
  -f vault-ent/vault-operator-values.yaml

# 4. Wait for controller to be ready
kubectl wait --for=condition=ready pod -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator --timeout=300s

# 5. Verify CRDs are installed
kubectl get crd | grep vault

# 6. Secrets will automatically resync
kubectl get vaultstaticsecret -A
kubectl get vaultdynamicsecret -A
```

### Application Recovery

#### Scenario 1: Application Namespace Deleted

**Symptoms:**
- Application namespace is gone
- All resources deleted
- Need to recreate from manifests

**Recovery:**

```bash
# 1. Recreate namespace
kubectl create namespace static-app-1

# 2. Restore from backup or Git
kubectl apply -f vault-ent/static-secrets/templates/ -n static-app-1

# 3. Verify resources created
kubectl get all,vaultauth,vaultstaticsecret -n static-app-1

# 4. Wait for secret sync
kubectl wait --for=condition=ready pod -n static-app-1 -l app=static-app --timeout=300s

# 5. Verify secret exists
kubectl get secret secretkv -n static-app-1
```

#### Scenario 2: Secret Sync Failure

**Symptoms:**
- VaultStaticSecret exists but K8s Secret not created
- VaultAuth shows errors
- Application cannot start

**Recovery:**

```bash
# 1. Check VaultAuth status
kubectl describe vaultauth static-auth -n static-app-1

# 2. Check VSO logs
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator

# 3. Verify Vault connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://vault.vault.svc.cluster.local:8200/v1/sys/health

# 4. Recreate VaultAuth if needed
kubectl delete vaultauth static-auth -n static-app-1
kubectl apply -f vault-ent/static-secrets/templates/vault-auth.yaml.tpl -n static-app-1

# 5. Verify secret sync
kubectl get secret secretkv -n static-app-1
```

### Complete Cluster Recovery

#### Scenario: Kubernetes Cluster Destroyed

**Symptoms:**
- Entire Kubernetes cluster is gone
- Need to rebuild from scratch
- Have backups of Vault data and manifests

**Recovery Steps:**

```bash
# 1. Recreate Kubernetes cluster
# Minikube:
minikube start --cpus=4 --memory=8192

# EKS:
cd eks/ && terraform apply

# GKE:
cd gke/ && terraform apply

# 2. Verify cluster is ready
kubectl get nodes

# 3. Reinstall Vault
helm install vault hashicorp/vault \
  --namespace vault \
  --create-namespace \
  -f vault-ent/vault-values.yaml

# 4. Wait for Vault pod
kubectl wait --for=condition=ready pod vault-0 -n vault --timeout=300s

# 5. Initialize Vault
kubectl exec -n vault vault-0 -- vault operator init -format=json > vault-init-new.json

# 6. Unseal Vault
for key in $(jq -r '.unseal_keys_b64[]' vault-init-new.json | head -3); do
    kubectl exec -n vault vault-0 -- vault operator unseal $key
done

# 7. Restore Vault data from backup
BACKUP_FILE="vault-snapshot-20260318-020000.snap"
kubectl cp "${BACKUP_FILE}" vault/vault-0:/tmp/restore.snap
kubectl exec -n vault vault-0 -- vault operator raft snapshot restore -force /tmp/restore.snap

# 8. Restart and unseal Vault
kubectl delete pod vault-0 -n vault
kubectl wait --for=condition=ready pod vault-0 -n vault --timeout=300s
for key in $(jq -r '.unseal_keys_b64[]' vault-init.json | head -3); do
    kubectl exec -n vault vault-0 -- vault operator unseal $key
done

# 9. Install VSO
helm install vault-secrets-operator hashicorp/vault-secrets-operator \
  --namespace vault-secrets-operator \
  --create-namespace \
  -f vault-ent/vault-operator-values.yaml

# 10. Deploy applications
task secrets

# 11. Verify everything is working
task verify
```

## Disaster Recovery Testing

### Regular DR Drills

**Quarterly DR Test Schedule:**

1. **Q1: Vault Pod Failure**
   - Simulate pod failure
   - Verify automatic recovery
   - Document recovery time

2. **Q2: Vault Data Restore**
   - Restore from backup
   - Verify data integrity
   - Test secret access

3. **Q3: VSO Failure**
   - Simulate VSO failure
   - Verify secret resync
   - Test application recovery

4. **Q4: Complete Cluster Recovery**
   - Rebuild cluster from scratch
   - Restore all components
   - Full end-to-end testing

### DR Test Checklist

```bash
# DR Test Checklist
# Date: ___________
# Tester: ___________

# Pre-Test
[ ] Backup current state
[ ] Document current configuration
[ ] Notify team of DR test
[ ] Set maintenance window

# Test Execution
[ ] Simulate failure scenario
[ ] Execute recovery procedures
[ ] Document recovery time (RTO)
[ ] Verify data integrity
[ ] Test application functionality

# Post-Test
[ ] Restore to normal operations
[ ] Document lessons learned
[ ] Update DR procedures
[ ] Update runbooks
[ ] Notify team of completion

# Metrics
Recovery Time Objective (RTO): _____ minutes
Recovery Point Objective (RPO): _____ minutes
Actual Recovery Time: _____ minutes
Data Loss: _____ (none/minimal/significant)
```

## Recovery Time Objectives (RTO)

| Scenario | Target RTO | Actual RTO | Notes |
|----------|-----------|------------|-------|
| Single pod failure | 5 minutes | ___ | Automatic recovery |
| Vault cluster failure | 30 minutes | ___ | Manual intervention |
| VSO failure | 10 minutes | ___ | Automatic resync |
| Complete cluster failure | 2 hours | ___ | Full rebuild |
| Data corruption | 1 hour | ___ | Restore from backup |

## Recovery Point Objectives (RPO)

| Data Type | Target RPO | Backup Frequency | Notes |
|-----------|-----------|------------------|-------|
| Vault data | 24 hours | Daily | Raft snapshots |
| Vault config | 1 hour | On change | Git commits |
| K8s manifests | 0 (no loss) | Continuous | Version control |
| Audit logs | 24 hours | Daily | Log aggregation |

## Best Practices

### Backup Best Practices

1. **Automate Everything**
   - Use CronJobs for scheduled backups
   - Automate backup verification
   - Automate backup rotation

2. **Test Regularly**
   - Perform quarterly DR drills
   - Test restore procedures
   - Verify backup integrity

3. **Store Securely**
   - Encrypt backups at rest
   - Use separate storage location
   - Implement access controls

4. **Monitor Backups**
   - Alert on backup failures
   - Track backup sizes
   - Monitor backup age

5. **Document Procedures**
   - Maintain runbooks
   - Document recovery steps
   - Update after each DR test

### Recovery Best Practices

1. **Have a Plan**
   - Document recovery procedures
   - Assign roles and responsibilities
   - Maintain contact lists

2. **Practice Recovery**
   - Regular DR drills
   - Test different scenarios
   - Train team members

3. **Verify Recovery**
   - Check data integrity
   - Test application functionality
   - Validate configurations

4. **Learn and Improve**
   - Document lessons learned
   - Update procedures
   - Share knowledge

## Monitoring and Alerting

### Backup Monitoring

```bash
# Check last backup age
LAST_BACKUP=$(ls -t backups/vault-snapshot-*.snap | head -1)
BACKUP_AGE=$(( ($(date +%s) - $(stat -f%m "$LAST_BACKUP" 2>/dev/null || stat -c%Y "$LAST_BACKUP" 2>/dev/null)) / 3600 ))

if [ $BACKUP_AGE -gt 24 ]; then
    echo "WARNING: Last backup is $BACKUP_AGE hours old"
fi

# Check backup size
BACKUP_SIZE=$(stat -f%z "$LAST_BACKUP" 2>/dev/null || stat -c%s "$LAST_BACKUP" 2>/dev/null)
if [ $BACKUP_SIZE -lt 1000000 ]; then
    echo "WARNING: Backup size is suspiciously small: $BACKUP_SIZE bytes"
fi
```

### Alert Configuration

**Prometheus AlertManager Rules:**

```yaml
groups:
- name: vault-backup
  rules:
  - alert: VaultBackupMissing
    expr: time() - vault_backup_last_success_timestamp > 86400
    for: 1h
    labels:
      severity: critical
    annotations:
      summary: "Vault backup is overdue"
      description: "Last successful backup was more than 24 hours ago"

  - alert: VaultBackupFailed
    expr: vault_backup_last_status != 0
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Vault backup failed"
      description: "Last backup attempt failed"
```

## Additional Resources

- [Vault Backup Guide](https://developer.hashicorp.com/vault/tutorials/operations/backup)
- [Vault Disaster Recovery](https://developer.hashicorp.com/vault/docs/enterprise/replication)
- [Kubernetes Backup Tools](https://kubernetes.io/docs/tasks/administer-cluster/backup/)
- [Velero - Kubernetes Backup](https://velero.io/)
