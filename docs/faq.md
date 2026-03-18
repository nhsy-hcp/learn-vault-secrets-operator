# Frequently Asked Questions (FAQ)

## General Questions

### What is Vault Secrets Operator (VSO)?

Vault Secrets Operator (VSO) is a Kubernetes operator that enables applications running in Kubernetes to consume secrets from HashiCorp Vault without requiring direct Vault API integration. VSO watches custom resources (VaultAuth, VaultStaticSecret, VaultDynamicSecret) and automatically syncs secrets from Vault to Kubernetes Secrets.

### Why use VSO instead of direct Vault integration?

**Benefits of VSO:**
- **Simplified Integration**: No need to modify application code to integrate with Vault
- **Automatic Secret Rotation**: VSO handles secret renewal and rotation automatically
- **Kubernetes-Native**: Uses standard Kubernetes Secrets that applications already understand
- **Centralized Management**: Manage secret access through Kubernetes CRDs
- **Caching**: Built-in caching reduces load on Vault
- **Multiple Secret Types**: Supports static, dynamic, and CSI-mounted secrets

### What's the difference between VSO and Vault Agent Injector?

| Feature | VSO | Vault Agent Injector |
|---------|-----|---------------------|
| **Approach** | Operator-based, syncs to K8s Secrets | Sidecar injection, writes to shared volume |
| **Secret Storage** | Kubernetes Secrets | Pod filesystem only |
| **Application Changes** | None required | None required |
| **Resource Overhead** | Single controller pod | Sidecar per pod |
| **Secret Types** | Static, Dynamic, CSI | Static, Dynamic |
| **Caching** | Controller-level | Per-pod |
| **Best For** | Most use cases | Legacy apps, specific requirements |

### What Vault version is required?

- **Minimum**: Vault 1.11+
- **Recommended**: Vault 1.15+ (latest stable)
- **Enterprise Features**: Vault Enterprise required for namespaces

### What Kubernetes versions are supported?

- **Minimum**: Kubernetes 1.24+
- **Recommended**: Kubernetes 1.28+
- **Tested Platforms**: Minikube, Amazon EKS, Google GKE, Azure AKS

## Architecture Questions

### How does the centralized JWT token reviewer work?

The centralized JWT token reviewer pattern uses a single service account (`vault` in the `vault` namespace) with `system:auth-delegator` permissions to validate all application service account tokens. This eliminates the need to grant token review permissions to every application service account.

**Flow:**
1. Application pod uses its service account token
2. VSO authenticates to Vault using the app SA token
3. Vault uses the centralized JWT token reviewer to validate the token
4. Upon successful validation, Vault issues a token with appropriate policies

### What are Vault namespaces and why are they used?

Vault Enterprise supports namespaces for multi-tenancy. In this project:
- **`vso` namespace**: Contains VSO-specific resources (transit engine for cache encryption)
- **`tn001` namespace**: Tenant namespace containing application secrets and configurations

Namespaces provide isolation, separate policies, and independent audit logs.

### How does secret caching work in VSO?

VSO implements client-side caching to reduce Vault API calls:
1. Secrets are cached in memory after first fetch
2. Cache is encrypted using Vault Transit engine (`vso-transit/vso-client-cache`)
3. Cache TTL is configurable (default: 5 minutes)
4. Cache is automatically invalidated when secrets change
5. Reduces Vault load by 70-90%

### What happens if Vault is unavailable?

**During Vault Outage:**
- Existing Kubernetes Secrets remain available
- Applications continue using cached secrets
- New secret syncs fail until Vault is restored
- VSO retries with exponential backoff

**After Vault Recovery:**
- VSO automatically reconnects
- Secret syncs resume
- No manual intervention required

## Deployment Questions

### Which platform should I use for production?

**Minikube:**
- ❌ Not for production
- ✅ Local development and testing
- ✅ Learning and experimentation

**Amazon EKS:**
- ✅ Production-ready
- ✅ AWS ecosystem integration
- ✅ Managed control plane
- ✅ Enterprise support

**Google GKE:**
- ✅ Production-ready
- ✅ GCP ecosystem integration
- ✅ Managed control plane
- ✅ Enterprise support

### How do I choose between static and dynamic secrets?

**Use Static Secrets When:**
- Secrets are manually managed
- Secrets don't expire
- Simple key-value pairs
- No automatic rotation needed
- Examples: API keys, configuration values

**Use Dynamic Secrets When:**
- Secrets should expire automatically
- Automatic rotation required
- Database credentials
- PKI certificates
- Cloud provider credentials
- Examples: PostgreSQL users, TLS certificates

### Should I use CSI driver or VSO?

**Use VSO (VaultStaticSecret/VaultDynamicSecret) When:**
- You want Kubernetes Secrets created
- Multiple pods need the same secret
- You need secret rotation
- Standard Kubernetes patterns preferred

**Use CSI Driver When:**
- Secrets should never touch Kubernetes Secrets
- Secrets only needed in pod filesystem
- Maximum security required
- Secrets are pod-specific

**Can Use Both:**
- Different secrets for different use cases
- CSI for highly sensitive data, VSO for standard secrets

### How many VSO controller replicas should I run?

**Development/Testing:**
- 1 replica is sufficient

**Production:**
- 2-3 replicas for high availability
- Enable leader election (automatic)
- Distribute across availability zones
- Consider workload size (1 replica can handle 100s of secrets)

## Secret Management Questions

### How do I update a secret?

**Static Secrets:**
```bash
# Update in Vault
kubectl exec -n vault vault-0 -- vault kv put -namespace=tn001 kvv2/webapp/config \
  username=new-user \
  password=new-password

# VSO syncs automatically (default: 5 minutes)
# Or force sync by deleting the K8s Secret
kubectl delete secret secretkv -n static-app-1

# Or restart the pod
kubectl rollout restart deployment -n static-app-1 static-app
```

**Dynamic Secrets:**
- Automatically rotated based on TTL
- No manual update needed
- VSO handles renewal and rotation

### How do I rotate credentials?

**Static Secrets:**
1. Update secret in Vault
2. Wait for VSO sync or force sync
3. Restart application pods to pick up new values

**Dynamic Secrets:**
1. Credentials automatically rotate based on TTL
2. VSO renews leases before expiration
3. Application pods automatically get new credentials
4. Old credentials are revoked after grace period

**Force Rotation:**
```bash
# Delete the Kubernetes Secret
kubectl delete secret vso-db-demo -n dynamic-app

# VSO generates new credentials immediately
```

### How do I handle secret sync failures?

**Check VSO Status:**
```bash
# Check VaultStaticSecret status
kubectl describe vaultstaticsecret vault-kv-app -n static-app-1

# Check VSO logs
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator
```

**Common Causes:**
1. **Authentication failure**: Check VaultAuth configuration
2. **Permission denied**: Verify Vault policies and roles
3. **Path not found**: Verify secret path exists in Vault
4. **Vault unavailable**: Check Vault pod status

**Resolution:**
- Fix the underlying issue
- VSO automatically retries
- No manual intervention needed after fix

### Can I use the same secret in multiple namespaces?

**Yes, with separate VaultStaticSecret resources:**

```yaml
# In namespace-1
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: shared-secret
  namespace: namespace-1
spec:
  vaultAuthRef: auth-1
  mount: kvv2
  path: shared/config
  destination:
    name: shared-secret

# In namespace-2
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: shared-secret
  namespace: namespace-2
spec:
  vaultAuthRef: auth-2
  mount: kvv2
  path: shared/config
  destination:
    name: shared-secret
```

Each namespace needs its own VaultAuth and appropriate Vault role.

## Authentication Questions

### How does Kubernetes authentication work?

1. Application pod has a service account
2. Service account has an associated JWT token
3. VSO uses this token to authenticate to Vault
4. Vault validates token using JWT token reviewer
5. Vault issues a Vault token with appropriate policies
6. VSO uses Vault token to access secrets

### What permissions does the JWT token reviewer need?

The JWT token reviewer service account needs:
- ClusterRole: `system:auth-delegator`
- Permissions: Token review API access
- Scope: Cluster-wide

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-reviewer-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: vault
  namespace: vault
```

### How do I troubleshoot authentication failures?

```bash
# 1. Verify JWT token reviewer exists
kubectl get secret vault-token-secret -n vault

# 2. Verify ClusterRoleBinding
kubectl get clusterrolebinding vault-reviewer-binding

# 3. Check Vault auth configuration
kubectl exec -n vault vault-0 -- vault read -namespace=tn001 auth/k8s-auth-mount/config

# 4. Test authentication manually
kubectl exec -n vault vault-0 -- vault write -namespace=tn001 auth/k8s-auth-mount/login \
  role=static-secret \
  jwt=$(kubectl get secret -n static-app-1 <sa-token-secret> -o jsonpath='{.data.token}' | base64 -d)

# 5. Check VSO logs
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator | grep -i auth
```

### Can I use multiple Vault instances?

Yes, using multiple VaultConnection resources:

```yaml
# Production Vault
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultConnection
metadata:
  name: vault-prod
spec:
  address: https://vault-prod.example.com:8200

# Development Vault
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultConnection
metadata:
  name: vault-dev
spec:
  address: https://vault-dev.example.com:8200
```

Reference the appropriate connection in VaultAuth resources.

## Performance Questions

### How many secrets can VSO handle?

**Typical Performance:**
- 100-500 secret syncs per minute
- 1000+ secrets with caching enabled
- Single controller can manage 1000+ VaultStaticSecret resources

**Scaling:**
- Horizontal: Add more VSO controller replicas
- Vertical: Increase controller resources
- Caching: Enable to reduce Vault load

### How do I optimize VSO performance?

**Enable Caching:**
```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultAuth
metadata:
  name: static-auth
spec:
  storageEncryption:
    mount: vso-transit
    keyName: vso-client-cache
```

**Adjust Refresh Interval:**
```yaml
apiVersion: secrets.hashicorp.com/v1beta1
kind: VaultStaticSecret
metadata:
  name: vault-kv-app
spec:
  refreshAfter: 5m  # Increase to reduce sync frequency
```

**Scale VSO:**
```bash
kubectl scale deployment -n vault-secrets-operator \
  vault-secrets-operator-controller-manager --replicas=3
```

### What's the impact on Vault performance?

**Without Caching:**
- 1 Vault API call per secret per sync interval
- Can overwhelm Vault with many secrets

**With Caching:**
- 70-90% reduction in Vault API calls
- Minimal impact on Vault performance
- Recommended for production

## Security Questions

### Is it safe to store secrets in Kubernetes Secrets?

**Kubernetes Secrets Security:**
- Base64 encoded (not encrypted) by default
- Stored in etcd
- Accessible to anyone with namespace access

**Recommendations:**
1. Enable etcd encryption at rest
2. Use RBAC to restrict Secret access
3. Enable audit logging
4. Consider CSI driver for highly sensitive secrets
5. Use network policies to restrict pod communication

### How are secrets encrypted?

**In Vault:**
- Encrypted at rest using storage backend encryption
- Encrypted in transit using TLS
- Access controlled by policies

**In Kubernetes:**
- Depends on cluster configuration
- Enable etcd encryption for encryption at rest
- Use TLS for API communication

**VSO Cache:**
- Encrypted using Vault Transit engine
- Encryption key stored in Vault
- Cache stored in controller memory

### What happens if someone deletes a Kubernetes Secret?

**VSO Behavior:**
- VSO detects deletion
- Automatically recreates the Secret
- Syncs data from Vault
- No data loss

**To Prevent Recreation:**
Delete the VaultStaticSecret/VaultDynamicSecret resource, not just the Secret.

### How do I audit secret access?

**Vault Audit Logs:**
```bash
# Enable audit logging
kubectl exec -n vault vault-0 -- vault audit enable file file_path=/vault/logs/audit.log

# View audit logs
kubectl exec -n vault vault-0 -- tail -f /vault/logs/audit.log
```

**Kubernetes Audit Logs:**
- Enable Kubernetes audit logging
- Track Secret access
- Monitor pod creation/deletion

**VSO Logs:**
```bash
# View VSO operations
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator
```

## Troubleshooting Questions

### Why is my pod stuck in ContainerCreating?

**Common Causes:**
1. **PVC not bound**: Check storage provisioner
2. **Image pull failure**: Check image name and registry access
3. **Secret not available**: Check VaultStaticSecret status
4. **CSI mount failure**: Check CSI provider logs

**Diagnosis:**
```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Why is Vault sealed after restart?

Vault seals automatically on restart for security. You must unseal it manually:

```bash
# Get unseal keys from vault-init.json
jq -r '.unseal_keys_b64[]' vault-init.json

# Unseal (requires 3 of 5 keys)
kubectl exec -n vault vault-0 -- vault operator unseal <key1>
kubectl exec -n vault vault-0 -- vault operator unseal <key2>
kubectl exec -n vault vault-0 -- vault operator unseal <key3>
```

**Production Solution:**
Implement auto-unseal using cloud KMS (AWS KMS, GCP Cloud KMS, Azure Key Vault).

### How do I recover from a failed deployment?

**Quick Recovery:**
```bash
# Uninstall everything
task uninstall

# Reinstall
task install

# Reconfigure
task config:vault

# Deploy secrets
task secrets
```

**Selective Recovery:**
```bash
# Reinstall just Vault
helm uninstall vault -n vault
task install:vault

# Reinstall just VSO
helm uninstall vault-secrets-operator -n vault-secrets-operator
task install:vso
```

### Where can I find logs?

**Vault Logs:**
```bash
kubectl logs -n vault vault-0
kubectl logs -n vault vault-0 -f  # Follow
```

**VSO Logs:**
```bash
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator -f
```

**Application Logs:**
```bash
kubectl logs -n static-app-1 -l app=static-app
kubectl logs -n dynamic-app -l app=dynamic-app
kubectl logs -n csi-app -l app=csi-app
```

**All Events:**
```bash
kubectl get events -A --sort-by='.lastTimestamp'
```

## Migration Questions

### How do I migrate from Vault Agent Injector to VSO?

1. **Deploy VSO** alongside Vault Agent Injector
2. **Create VaultAuth** resources for each namespace
3. **Create VaultStaticSecret** resources for each secret
4. **Update application deployments** to use Kubernetes Secrets instead of injected files
5. **Test thoroughly** before removing Vault Agent Injector
6. **Remove Vault Agent Injector** annotations from pods
7. **Uninstall Vault Agent Injector**

### Can I use both VSO and Vault Agent Injector?

Yes, they can coexist:
- Use VSO for new applications
- Keep Vault Agent Injector for legacy applications
- Gradually migrate to VSO
- No conflicts between the two

### How do I migrate from external secrets to Vault?

1. **Store secrets in Vault** (KV v2 engine)
2. **Create Vault policies** for secret access
3. **Create Kubernetes auth roles** for applications
4. **Deploy VSO** and configure VaultAuth
5. **Create VaultStaticSecret** resources
6. **Update applications** to use new secret names
7. **Remove external secret resources**
8. **Verify** all applications work correctly

## Cost Questions

### What are the infrastructure costs?

See platform-specific deployment guides:
- [Minikube](minikube-local-dev.md#comparison-minikube-vs-cloud-platforms): Free (local resources)
- [EKS](aws-eks-deployment.md#cost-estimation): ~$300-350/month
- [GKE](gke-deployment.md#cost-estimation): ~$160-210/month

### How can I reduce costs?

**Development:**
- Use Minikube for local development
- Use spot/preemptible instances
- Scale down during off-hours
- Use smaller instance types

**Production:**
- Right-size resources based on actual usage
- Use committed use discounts
- Enable cluster autoscaling
- Optimize storage class selection
- Monitor and eliminate waste

## Additional Resources

For more detailed information, refer to the comprehensive documentation:
- [Architecture](architecture.md)
- [AWS EKS Deployment](aws-eks-deployment.md)
- [GKE Deployment](gke-deployment.md)
- [Minikube Local Dev](minikube-local-dev.md)
- [Troubleshooting](troubleshooting.md)
- [Testing & Validation](testing-validation.md)
- [Backup & Recovery](backup-recovery.md)
- [Monitoring](monitoring.md)
