# Troubleshooting Guide

## Overview

This guide provides comprehensive troubleshooting procedures for common issues encountered when deploying and operating HashiCorp Vault and Vault Secrets Operator (VSO) on Kubernetes across Minikube, Amazon EKS, and Google GKE platforms.

## General Troubleshooting Approach

### Systematic Debugging Process

1. **Identify the Problem**
   - What is not working as expected?
   - When did the issue start?
   - What changed recently?

2. **Gather Information**
   - Check pod status and events
   - Review logs from affected components
   - Verify resource configurations
   - Check network connectivity

3. **Isolate the Issue**
   - Is it affecting one component or multiple?
   - Is it platform-specific or general?
   - Can you reproduce the issue?

4. **Apply Solution**
   - Start with least disruptive fixes
   - Test changes incrementally
   - Document what worked

5. **Verify Resolution**
   - Confirm the issue is resolved
   - Check for side effects
   - Monitor for recurrence

## Common Issues by Component

### Vault Issues

#### Issue: Vault Pods Not Starting

**Symptoms:**
- Vault pods stuck in `Pending`, `CrashLoopBackOff`, or `Error` state
- Pods fail to initialize

**Common Causes:**
1. PVC not bound
2. Insufficient node resources
3. License file missing or invalid
4. Image pull errors
5. Configuration errors

**Diagnostic Commands:**
```bash
# Check pod status
kubectl get pods -n vault

# Describe pod for detailed events
kubectl describe pod vault-0 -n vault

# Check pod logs
kubectl logs vault-0 -n vault

# Check previous logs if pod restarted
kubectl logs vault-0 -n vault --previous

# Check PVC status
kubectl get pvc -n vault

# Check node resources
kubectl top nodes
kubectl describe node <node-name>
```

**Solutions:**

**PVC Not Bound:**
```bash
# Check PVC events
kubectl describe pvc data-vault-0 -n vault

# Verify storage class exists
kubectl get storageclass

# Check storage provisioner logs (platform-specific)
# Minikube:
kubectl logs -n kube-system -l app=storage-provisioner

# EKS:
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# GKE:
kubectl logs -n kube-system -l app=gcp-compute-persistent-disk-csi-driver
```

**Insufficient Resources:**
```bash
# Check node capacity
kubectl describe nodes | grep -A 5 "Allocated resources"

# Reduce Vault resource requests
helm upgrade vault hashicorp/vault \
  --namespace vault \
  --set server.resources.requests.memory=256Mi \
  --set server.resources.requests.cpu=250m
```

**License File Missing:**
```bash
# Verify license file exists
ls -la vault-ent/vault-license.lic

# Check license file is mounted
kubectl exec -n vault vault-0 -- ls -la /vault/userconfig/vault-license/

# Recreate license secret if needed
kubectl delete secret vault-license -n vault
kubectl create secret generic vault-license \
  --from-file=license=vault-ent/vault-license.lic \
  -n vault
```

**Image Pull Errors:**
```bash
# Check image pull status
kubectl get events -n vault | grep -i pull

# Verify image exists
kubectl describe pod vault-0 -n vault | grep -A 5 "Image:"

# Check image pull secrets
kubectl get secrets -n vault
```

#### Issue: Vault Sealed After Restart

**Symptoms:**
- Vault pods running but sealed
- API returns 503 Service Unavailable
- Vault status shows `Sealed: true`

**Diagnostic Commands:**
```bash
# Check Vault seal status
kubectl exec -n vault vault-0 -- vault status

# Check Vault logs
kubectl logs -n vault vault-0 | grep -i seal
```

**Solutions:**

**Manual Unseal:**
```bash
# Get unseal keys from vault-init.json
jq -r '.unseal_keys_b64[]' vault-init.json

# Unseal Vault (requires 3 of 5 keys)
kubectl exec -n vault vault-0 -- vault operator unseal <key1>
kubectl exec -n vault vault-0 -- vault operator unseal <key2>
kubectl exec -n vault vault-0 -- vault operator unseal <key3>

# Verify unsealed
kubectl exec -n vault vault-0 -- vault status
```

**Auto-Unseal (Production):**
Consider implementing auto-unseal using cloud KMS:
- AWS KMS for EKS
- Cloud KMS for GKE
- Transit engine for Vault-to-Vault unseal

#### Issue: Vault Authentication Failures

**Symptoms:**
- Applications cannot authenticate to Vault
- `permission denied` errors
- Token validation failures

**Diagnostic Commands:**
```bash
# Check Kubernetes auth configuration
kubectl exec -n vault vault-0 -- vault read tn001/auth/k8s-auth-mount/config

# List auth roles
kubectl exec -n vault vault-0 -- vault list tn001/auth/k8s-auth-mount/role

# Read specific role
kubectl exec -n vault vault-0 -- vault read tn001/auth/k8s-auth-mount/role/static-secret

# Check JWT token reviewer
kubectl get secret vault-token-secret -n vault
kubectl describe clusterrolebinding vault-reviewer-binding
```

**Solutions:**

**JWT Token Reviewer Issues:**
```bash
# Verify service account exists
kubectl get sa vault -n vault

# Verify ClusterRoleBinding
kubectl get clusterrolebinding vault-reviewer-binding

# Recreate token secret if needed
kubectl delete secret vault-token-secret -n vault
kubectl apply -f vault-ent/vault-jwt-secret.yaml

# Update Vault auth config with new token
export JWT_TOKEN=$(kubectl get secret vault-token-secret -n vault -o jsonpath='{.data.token}' | base64 -d)
kubectl exec -n vault vault-0 -- vault write tn001/auth/k8s-auth-mount/config \
  kubernetes_host="https://kubernetes.default.svc" \
  token_reviewer_jwt="$JWT_TOKEN"
```

**Role Configuration Issues:**
```bash
# Verify role exists
kubectl exec -n vault vault-0 -- vault read tn001/auth/k8s-auth-mount/role/static-secret

# Recreate role if needed
kubectl exec -n vault vault-0 -- vault write tn001/auth/k8s-auth-mount/role/static-secret \
  bound_service_account_names=static-app-sa \
  bound_service_account_namespaces=static-app-* \
  policies=static-secret \
  ttl=1h
```

**Policy Issues:**
```bash
# List policies
kubectl exec -n vault vault-0 -- vault policy list -namespace=tn001

# Read policy
kubectl exec -n vault vault-0 -- vault policy read -namespace=tn001 static-secret

# Update policy if needed
cat vault-ent/static-secrets/static-secret.hcl | \
  kubectl exec -i -n vault vault-0 -- vault policy write -namespace=tn001 static-secret -
```

### VSO Issues

#### Issue: VSO Controller Not Starting

**Symptoms:**
- VSO controller pods not running
- CRDs not registered
- Secrets not syncing

**Diagnostic Commands:**
```bash
# Check VSO pod status
kubectl get pods -n vault-secrets-operator

# Describe pod
kubectl describe pod -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator

# Check VSO logs
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator

# Check CRDs
kubectl get crd | grep vault
```

**Solutions:**

**CRD Installation Issues:**
```bash
# Verify CRDs are installed
kubectl get crd vaultauths.secrets.hashicorp.com
kubectl get crd vaultconnections.secrets.hashicorp.com
kubectl get crd vaultstaticsecrets.secrets.hashicorp.com
kubectl get crd vaultdynamicsecrets.secrets.hashicorp.com

# Reinstall VSO if CRDs missing
helm uninstall vault-secrets-operator -n vault-secrets-operator
helm install vault-secrets-operator hashicorp/vault-secrets-operator \
  --namespace vault-secrets-operator \
  --create-namespace
```

**Resource Issues:**
```bash
# Check node resources
kubectl top nodes

# Reduce VSO resource requests
helm upgrade vault-secrets-operator hashicorp/vault-secrets-operator \
  --namespace vault-secrets-operator \
  --set controller.manager.resources.requests.memory=64Mi \
  --set controller.manager.resources.requests.cpu=50m
```

#### Issue: Secrets Not Syncing

**Symptoms:**
- VaultStaticSecret or VaultDynamicSecret resources created but no K8s Secret
- Secret sync status shows errors
- VSO logs show authentication or permission errors

**Diagnostic Commands:**
```bash
# Check VaultStaticSecret status
kubectl get vaultstaticsecret -A
kubectl describe vaultstaticsecret vault-kv-app -n static-app-1

# Check VaultAuth status
kubectl get vaultauth -A
kubectl describe vaultauth static-auth -n static-app-1

# Check VaultConnection status
kubectl get vaultconnection -A
kubectl describe vaultconnection vault-connection -n static-app-1

# Check VSO logs
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator -f

# Check if K8s Secret was created
kubectl get secret secretkv -n static-app-1
```

**Solutions:**

**VaultAuth Configuration Issues:**
```bash
# Verify VaultAuth resource
kubectl get vaultauth static-auth -n static-app-1 -o yaml

# Check service account exists
kubectl get sa static-app-sa -n static-app-1

# Verify service account token
kubectl get secret -n static-app-1 | grep static-app-sa

# Check VaultAuth status
kubectl describe vaultauth static-auth -n static-app-1
```

**VaultConnection Issues:**
```bash
# Verify VaultConnection
kubectl get vaultconnection vault-connection -n static-app-1 -o yaml

# Test connectivity to Vault
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -k http://vault.vault.svc.cluster.local:8200/v1/sys/health

# Check Vault service
kubectl get svc -n vault vault
```

**Path or Policy Issues:**
```bash
# Verify secret path exists in Vault
kubectl exec -n vault vault-0 -- vault kv get -namespace=tn001 kvv2/webapp/config

# Verify policy allows access
kubectl exec -n vault vault-0 -- vault policy read -namespace=tn001 static-secret

# Test authentication manually
kubectl exec -n vault vault-0 -- vault write -namespace=tn001 auth/k8s-auth-mount/login \
  role=static-secret \
  jwt=<service-account-token>
```

**VSO Cache Issues:**
```bash
# Check VSO cache configuration
kubectl get vaultauth -A -o yaml | grep -A 5 cache

# Clear VSO cache by restarting controller
kubectl rollout restart deployment -n vault-secrets-operator vault-secrets-operator-controller-manager

# Check transit encryption
kubectl exec -n vault vault-0 -- vault read vso/transit/keys/vso-client-cache
```

#### Issue: Dynamic Secrets Not Rotating

**Symptoms:**
- Dynamic credentials not being renewed
- Credentials expire and applications fail
- VaultDynamicSecret shows stale lease

**Diagnostic Commands:**
```bash
# Check VaultDynamicSecret status
kubectl describe vaultdynamicsecret vso-db-demo -n dynamic-app

# Check lease information
kubectl get secret vso-db-demo -n dynamic-app -o yaml | grep -A 10 metadata

# Check VSO logs for renewal attempts
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator | grep -i renew

# Check Vault lease
kubectl exec -n vault vault-0 -- vault list -namespace=tn001 sys/leases/lookup/db/creds/dev-postgres
```

**Solutions:**

**Renewal Configuration:**
```bash
# Update VaultDynamicSecret with renewal settings
kubectl patch vaultdynamicsecret vso-db-demo -n dynamic-app --type=merge -p '
spec:
  renewalPercent: 67
  refreshAfter: 30s
'

# Verify renewal is working
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator -f | grep -i renew
```

**Lease Issues:**
```bash
# Check database role TTL
kubectl exec -n vault vault-0 -- vault read -namespace=tn001 db/roles/dev-postgres

# Update role with appropriate TTL
kubectl exec -n vault vault-0 -- vault write -namespace=tn001 db/roles/dev-postgres \
  db_name=postgres \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";" \
  default_ttl=1h \
  max_ttl=24h
```

### CSI Driver Issues

#### Issue: CSI Volumes Not Mounting

**Symptoms:**
- Pods stuck in `ContainerCreating` state
- `FailedMount` events
- Secrets not available in pod filesystem

**Diagnostic Commands:**
```bash
# Check pod events
kubectl describe pod -n csi-app -l app=csi-app

# Check CSI provider logs
kubectl logs -n vault -l app.kubernetes.io/name=vault-csi-provider

# Check CSI node driver logs
kubectl logs -n kube-system -l app=csi-secrets-store

# Check SecretProviderClass
kubectl get secretproviderclass -n csi-app
kubectl describe secretproviderclass vault-database -n csi-app
```

**Solutions:**

**CSI Provider Not Running:**
```bash
# Check CSI provider pod
kubectl get pods -n vault -l app.kubernetes.io/name=vault-csi-provider

# Restart CSI provider if needed
kubectl rollout restart daemonset -n vault vault-csi-provider

# Verify CSI provider is healthy
kubectl logs -n vault -l app.kubernetes.io/name=vault-csi-provider
```

**SecretProviderClass Configuration:**
```bash
# Verify SecretProviderClass
kubectl get secretproviderclass vault-database -n csi-app -o yaml

# Check authentication configuration
kubectl describe secretproviderclass vault-database -n csi-app | grep -A 10 parameters

# Test Vault connectivity from CSI provider
kubectl exec -n vault -l app.kubernetes.io/name=vault-csi-provider -- \
  curl -k http://vault.vault.svc.cluster.local:8200/v1/sys/health
```

**Service Account Issues:**
```bash
# Verify service account exists
kubectl get sa csi-app-sa -n csi-app

# Check role binding in Vault
kubectl exec -n vault vault-0 -- vault read -namespace=tn001 auth/k8s-auth-mount/role/csi-secret

# Test authentication
kubectl exec -n vault vault-0 -- vault write -namespace=tn001 auth/k8s-auth-mount/login \
  role=csi-secret \
  jwt=$(kubectl get secret -n csi-app $(kubectl get sa csi-app-sa -n csi-app -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d)
```

### Application Issues

#### Issue: Application Cannot Read Secrets

**Symptoms:**
- Application logs show missing environment variables
- Application cannot access mounted secrets
- Application fails to start

**Diagnostic Commands:**
```bash
# Check if secret exists
kubectl get secret secretkv -n static-app-1

# Verify secret content
kubectl get secret secretkv -n static-app-1 -o yaml

# Check pod environment variables
kubectl exec -n static-app-1 -l app=static-app -- env | grep -i secret

# Check mounted volumes
kubectl exec -n static-app-1 -l app=static-app -- ls -la /secrets/static

# Check application logs
kubectl logs -n static-app-1 -l app=static-app
```

**Solutions:**

**Secret Not Mounted:**
```bash
# Verify pod spec includes secret mount
kubectl get pod -n static-app-1 -l app=static-app -o yaml | grep -A 10 volumes

# Check if secret is referenced correctly
kubectl describe pod -n static-app-1 -l app=static-app | grep -A 5 "Mounts:"

# Restart pod to remount secrets
kubectl rollout restart deployment -n static-app-1 static-app
```

**Environment Variable Issues:**
```bash
# Verify secret keys match environment variable names
kubectl get secret secretkv -n static-app-1 -o jsonpath='{.data}' | jq 'keys'

# Check deployment env configuration
kubectl get deployment static-app -n static-app-1 -o yaml | grep -A 20 env

# Update deployment if needed
kubectl set env deployment/static-app -n static-app-1 --from=secret/secretkv
```

## Platform-Specific Issues

### Minikube Issues

#### Issue: Minikube Won't Start

**Symptoms:**
- `minikube start` fails
- VM creation errors
- Driver issues

**Solutions:**
```bash
# Check minikube logs
minikube logs

# Delete and recreate
minikube delete
minikube start --driver=docker --cpus=4 --memory=8192

# Try different driver
minikube start --driver=virtualbox

# Check system resources
free -h  # Linux
vm_stat  # macOS
```

#### Issue: Service Not Accessible

**Symptoms:**
- Cannot access Vault UI
- LoadBalancer stuck in Pending
- NodePort not responding

**Solutions:**
```bash
# Use minikube tunnel
sudo minikube tunnel

# Or use minikube service
minikube service vault -n vault

# Or use port-forward
kubectl port-forward -n vault svc/vault 8200:8200
```

### EKS Issues

#### Issue: EBS CSI Driver Not Working

**Symptoms:**
- PVCs stuck in Pending
- Volume attachment failures
- Storage class issues

**Solutions:**
```bash
# Check EBS CSI driver
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# Check IAM role
kubectl describe sa ebs-csi-controller-sa -n kube-system | grep -i role

# Verify storage class
kubectl get storageclass gp2

# Check AWS permissions
aws iam get-role --role-name AmazonEKS_EBS_CSI_DriverRole
```

#### Issue: Load Balancer Not Provisioning

**Symptoms:**
- Service stuck in Pending
- No external IP assigned
- ALB controller errors

**Solutions:**
```bash
# Check ALB controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check subnet tags
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>"

# Verify IAM role
kubectl describe sa aws-load-balancer-controller -n kube-system
```

### GKE Issues

#### Issue: Workload Identity Not Working

**Symptoms:**
- Pods cannot access GCP services
- Authentication failures
- IAM permission errors

**Solutions:**
```bash
# Verify Workload Identity enabled
gcloud container clusters describe vault-gke-cluster --region us-central1 --format="value(workloadIdentityConfig.workloadPool)"

# Check service account annotation
kubectl get sa vault -n vault -o yaml | grep iam.gke.io

# Verify IAM binding
gcloud iam service-accounts get-iam-policy vault-gke-sa@PROJECT_ID.iam.gserviceaccount.com
```

#### Issue: Persistent Disk Not Attaching

**Symptoms:**
- PVCs stuck in Pending
- Disk attachment timeouts
- Zone mismatch errors

**Solutions:**
```bash
# Check PVC events
kubectl describe pvc data-vault-0 -n vault

# Verify storage class
kubectl get storageclass standard-rwo

# Check disk quota
gcloud compute project-info describe --project=PROJECT_ID | grep DISKS_TOTAL_GB

# Verify zones match
kubectl get nodes -o wide
kubectl get pvc -A -o wide
```

## Network Issues

### DNS Resolution Failures

**Symptoms:**
- Services cannot resolve each other
- `nslookup` fails
- Connection timeouts

**Diagnostic Commands:**
```bash
# Test DNS from pod
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup vault.vault.svc.cluster.local

# Check CoreDNS
kubectl get pods -n kube-system -l k8s-app=kube-dns

# Check CoreDNS logs
kubectl logs -n kube-system -l k8s-app=kube-dns
```

**Solutions:**
```bash
# Restart CoreDNS
kubectl rollout restart deployment -n kube-system coredns

# Check CoreDNS ConfigMap
kubectl get configmap coredns -n kube-system -o yaml

# Verify service exists
kubectl get svc vault -n vault
```

### Network Policy Blocking Traffic

**Symptoms:**
- Pods cannot communicate
- Connection refused errors
- Timeout errors

**Diagnostic Commands:**
```bash
# Check network policies
kubectl get networkpolicy -A

# Describe network policy
kubectl describe networkpolicy -n vault

# Test connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://vault.vault.svc.cluster.local:8200/v1/sys/health
```

**Solutions:**
```bash
# Temporarily disable network policy
kubectl delete networkpolicy <policy-name> -n <namespace>

# Update network policy to allow traffic
kubectl edit networkpolicy <policy-name> -n <namespace>

# Verify connectivity after changes
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://vault.vault.svc.cluster.local:8200/v1/sys/health
```

## Performance Issues

### High API Call Rate

**Symptoms:**
- Vault API rate limiting
- Slow secret sync
- High CPU usage on Vault

**Solutions:**
```bash
# Enable VSO caching
kubectl patch vaultauth static-auth -n static-app-1 --type=merge -p '
spec:
  storageEncryption:
    mount: vso-transit
    keyName: vso-client-cache
'

# Increase cache TTL
kubectl patch vaultstaticsecret vault-kv-app -n static-app-1 --type=merge -p '
spec:
  refreshAfter: 5m
'

# Scale Vault horizontally (HA mode)
helm upgrade vault hashicorp/vault \
  --namespace vault \
  --set server.ha.enabled=true \
  --set server.ha.replicas=3
```

### Storage I/O Bottleneck

**Symptoms:**
- Slow Vault operations
- High disk latency
- Audit log delays

**Solutions:**
```bash
# Use faster storage class
# EKS: Switch to gp3 or io1
# GKE: Switch to premium-rwo

# Increase IOPS (EKS)
kubectl patch pvc data-vault-0 -n vault --type=merge -p '
spec:
  resources:
    requests:
      storage: 20Gi
'

# Disable audit logging temporarily (not recommended for production)
kubectl exec -n vault vault-0 -- vault audit disable file
```

## Debugging Tools and Commands

### Essential Debugging Commands

```bash
# Get all resources in namespace
kubectl get all -n <namespace>

# Get events sorted by time
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Describe resource for detailed info
kubectl describe <resource-type> <resource-name> -n <namespace>

# Get logs with timestamps
kubectl logs <pod-name> -n <namespace> --timestamps

# Follow logs in real-time
kubectl logs <pod-name> -n <namespace> -f

# Get previous logs (if pod restarted)
kubectl logs <pod-name> -n <namespace> --previous

# Execute command in pod
kubectl exec -it <pod-name> -n <namespace> -- <command>

# Port forward for local access
kubectl port-forward -n <namespace> <pod-name> <local-port>:<pod-port>

# Get resource as YAML
kubectl get <resource-type> <resource-name> -n <namespace> -o yaml

# Get resource as JSON with jq
kubectl get <resource-type> <resource-name> -n <namespace> -o json | jq '.'
```

### Vault-Specific Commands

```bash
# Check Vault status
kubectl exec -n vault vault-0 -- vault status

# List auth methods
kubectl exec -n vault vault-0 -- vault auth list -namespace=tn001

# List secret engines
kubectl exec -n vault vault-0 -- vault secrets list -namespace=tn001

# Read secret
kubectl exec -n vault vault-0 -- vault kv get -namespace=tn001 kvv2/webapp/config

# List policies
kubectl exec -n vault vault-0 -- vault policy list -namespace=tn001

# Read policy
kubectl exec -n vault vault-0 -- vault policy read -namespace=tn001 static-secret

# Test authentication
kubectl exec -n vault vault-0 -- vault write -namespace=tn001 auth/k8s-auth-mount/login \
  role=static-secret \
  jwt=<token>

# Check audit logs
kubectl exec -n vault vault-0 -- cat /vault/logs/audit.log | tail -n 50
```

### VSO-Specific Commands

```bash
# Get all VSO resources
kubectl get vaultauth,vaultconnection,vaultstaticsecret,vaultdynamicsecret -A

# Check VSO controller logs
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator -f

# Get VSO metrics
kubectl port-forward -n vault-secrets-operator svc/vault-secrets-operator-metrics-service 8080:8080
curl http://localhost:8080/metrics

# Check VSO version
kubectl get deployment -n vault-secrets-operator vault-secrets-operator-controller-manager -o jsonpath='{.spec.template.spec.containers[0].image}'
```

## Getting Help

### Log Collection

```bash
# Collect all logs for support
mkdir -p debug-logs

# Vault logs
kubectl logs -n vault vault-0 > debug-logs/vault.log

# VSO logs
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator > debug-logs/vso.log

# Application logs
kubectl logs -n static-app-1 -l app=static-app > debug-logs/static-app.log
kubectl logs -n dynamic-app -l app=dynamic-app > debug-logs/dynamic-app.log
kubectl logs -n csi-app -l app=csi-app > debug-logs/csi-app.log

# Events
kubectl get events -A --sort-by='.lastTimestamp' > debug-logs/events.log

# Resource descriptions
kubectl describe pod -n vault vault-0 > debug-logs/vault-pod-describe.log
kubectl describe vaultstaticsecret -A > debug-logs/vaultstaticsecret-describe.log

# Create archive
tar czf debug-logs-$(date +%Y%m%d-%H%M%S).tar.gz debug-logs/
```

## Additional Resources

- [Vault Troubleshooting Guide](https://developer.hashicorp.com/vault/docs/troubleshooting)
- [VSO Troubleshooting](https://developer.hashicorp.com/vault/docs/platform/k8s/vso/troubleshooting)
- [Kubernetes Debugging Guide](https://kubernetes.io/docs/tasks/debug/)
