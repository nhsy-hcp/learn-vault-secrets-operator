# Vault Secrets Operator for Kubernetes

This repository demonstrates HashiCorp Vault Secrets Operator (VSO) integration with Kubernetes, showcasing static secrets, dynamic secrets, and CSI driver functionality with automated workflows.

## Overview

The Vault Secrets Operator enables Kubernetes applications to consume secrets from HashiCorp Vault through native Kubernetes resources. This project includes complete automation for deploying and managing Vault with VSO on Minikube, Amazon EKS, and Google GKE.

## Features

- Static KV secrets synchronization with VaultStaticSecret resources
- Dynamic database credentials with automatic rotation
- PKI certificate generation and management
- CSI driver integration for volume-mounted secrets
- JWT authentication with Kubernetes service accounts
- Encrypted client cache using Vault Transit engine
- Automated deployment and teardown workflows

## Prerequisites

### Vault Enterprise License
A Vault Enterprise license is required for this lab. You must place a valid `vault-license.lic` file in the `vault-ent/` directory before running the installation tasks.
This enables vault namespace and vault secrets operator csi features.

```bash
vault-ent/
└── vault-license.lic  # Required: Vault Enterprise license file
```

The license file is automatically loaded during Vault configuration via the `task config:vault` command.

### Required Tools

Install the following tools:

- kubectl
- helm
- minikube (for local development)
- jq
- task (taskfile.dev)
- AWS CLI (for EKS deployments)
- Google Cloud CLI (for GKE deployments)
- Terraform CLI

## Quick Start

### Local Development with Minikube

```bash
# Start minikube cluster
task minikube
task install
task secrets
task verify
```

### Amazon EKS Deployment

```bash
# Deploy complete EKS infrastructure and install Vault/VSO
task eks:all
task install
task secrets
task verify
```

### Google GKE Deployment

```bash
# Deploy complete GKE infrastructure and install Vault/VSO
task gke:all
task install
task secrets
task verify
```

## Project Structure

```
.
├── Taskfile.yml                    # Task automation definitions
├── vault-ent/                      # Vault Enterprise configurations
│   ├── static-secrets/            # Static secret manifests
│   ├── dynamic-secrets/           # Dynamic secret manifests
│   └── csi/                       # CSI driver configurations
├── eks/                           # EKS infrastructure (Terraform)
└── gke/                           # GKE infrastructure (Terraform)
```

## Architecture

### Architecture Diagram #TODO
![architecture diagram](diagram.png)

### Authentication Model

The project uses a centralized JWT token reviewer service account with dedicated Vault roles per application type:

- Service Account: `vault` in `vault` namespace
- ClusterRoleBinding: `vault-reviewer-binding` with `system:auth-delegator` role
- Token Secret: `vault-token-secret` (long-lived service account token)
- All Kubernetes auth mounts use this token for authentication
- Benefits: Better persistence across cluster restarts, EKS/GKE compatibility, consistent authentication

#### Role Architecture
Each application type has a dedicated Vault role with specific policies and service account bindings:
- **Static Secrets**: Role `static-secret` with policy `static-secret`, service account `static-app-sa`
  - Uses glob pattern matching for namespaces (`static-app-*`) to support multiple static app instances
- **Dynamic Secrets**: Role `dynamic-secret` with policy `dynamic-secret`, service account `dynamic-app-sa`
- **CSI Integration**: Role `csi-secret` with policy `csi-secret`, service account `csi-app-sa`

#### Authentication Flow
1. **JWT Token Reviewer**: A centralized service account with `system:auth-delegator` permissions provides a long-lived JWT token
2. **All Kubernetes auth mounts** in Vault (both `vso` and `tn001` namespaces) use this token for token review operations
3. **Application service accounts** authenticate to Vault using their own service account tokens with dedicated roles, which Vault validates using the JWT token reviewer

#### Static Secrets Flow
1. VSO controller watches `VaultStaticSecret` resources across multiple static app instances
2. Application service account (`static-app-sa`) in each namespace (`static-app-1`, `static-app-2`, `static-app-3`) authenticates via `VaultAuth` to Vault's `k8s-auth-mount` in `tn001` namespace using the `static-secret` role
3. The `static-secret` role uses glob pattern matching (`static-app-*`) to authorize all static app instances
4. VSO reads secrets from `kvv2/webapp/config` path
5. Secrets are synced to Kubernetes `Secret` resource (`secretkv`) in each namespace
6. Application pod mounts the secret as environment variables and to `/secrets/static` volume mount

#### Dynamic Secrets Flow
1. VSO controller watches `VaultDynamicSecret` resources
2. Application service account (`dynamic-app-sa`) in `dynamic-app` namespace authenticates via `VaultAuth` to Vault's `k8s-auth-mount` in `tn001` namespace using the `dynamic-secret` role
3. VSO requests:
   - Dynamic database credentials from `db/creds/dev-postgres`
   - PKI certificates from `pki/issue/example-dot-com`
4. Credentials are synced to Kubernetes `Secret` resources
5. Application pod mounts database credentials to `/secrets/dynamic/db` and PKI certificates to `/secrets/dynamic/tls` volume mounts
6. Credentials automatically rotate based on TTL

#### CSI Driver Flow
1. Application pod defines CSI volume with `SecretProviderClass`
2. CSI node driver intercepts mount request
3. Application service account (`csi-app-sa`) in `csi-app` namespace authenticates to Vault's `k8s-auth-mount` in `tn001` namespace using the `csi-secret` role
4. Vault CSI Provider fetches secrets from `kvv2/db-creds`
5. Secrets are mounted directly to pod filesystem at `/secrets/static`
6. No Kubernetes `Secret` resource is created

#### Encrypted Client Cache
1. VSO controller authenticates to Vault's `vso` namespace
2. Uses Transit engine (`vso-transit`) to encrypt cached client data
3. Improves performance and reduces Vault API calls

### Platform-Specific Storage Classes

The Vault installation automatically detects the Kubernetes platform and configures the appropriate storage class for persistent storage:

**Detection Method**: The `install:vault` task analyzes the kubectl context to identify the platform:
- **Minikube**: Context contains "minikube"
- **EKS**: Context contains "eks" or "arn:aws"
- **GKE**: Context contains "gke"

**Storage Class Configuration**:
- **EKS**: Uses `gp2` storage class (AWS EBS General Purpose SSD)
  - Explicitly set via `--set server.dataStorage.storageClass=gp2`
  - Compatible with AWS EBS CSI driver
- **GKE**: Uses cluster default storage class (typically `standard-rwo`)
  - No explicit storageClass override
  - Relies on GKE's default persistent disk provisioning
- **Minikube**: Uses `standard` storage class (minikube-hostpath provisioner)
  - No explicit storageClass override
  - Automatically provided by minikube

### Namespaces

- `vault` - Vault and CSI provider pods
- `vault-secrets-operator` - VSO controller
- `static-app-1`, `static-app-2`, `static-app-3` - Multiple static KV secrets demonstration instances (configurable count)
- `dynamic-app` - Dynamic database and PKI secrets demonstration
- `csi-app` - CSI driver integration demonstration

### Vault Configuration

**Namespaces:**
- `vso` - VSO configuration and transit encryption
- `tn001` - Tenant namespace for application secrets (static, dynamic, CSI)

**Static Secrets:**
- Namespace: `tn001`
- Mount: `kvv2`
- Path: `kvv2/webapp/config`
- Auth role: `static-secret` (dedicated role with `static-secret` policy only)
- Service account: `static-app-sa` (in namespaces `static-app-1`, `static-app-2`, `static-app-3`)
- Bound claims: Uses glob pattern `static-app-*` to authorize multiple instances

**Dynamic Database Secrets:**
- Namespace: `tn001`
- Mount: `db`
- Path: `creds/dev-postgres`
- Auth role: `dynamic-secret` (dedicated role with `dynamic-secret` policy only)
- Service account: `dynamic-app-sa` (in namespace `dynamic-app`)
- PostgreSQL deployment included

**PKI Secrets:**
- Namespace: `tn001`
- Mount: `pki`
- Role: `example-dot-com`

**CSI Driver:**
- Namespace: `tn001`
- Mount: `kvv2`
- Path: `db-creds`
- Auth role: `csi-secret` (dedicated role with `csi-secret` policy only)
- Service account: `csi-app-sa` (in namespace `csi-app`)

**Encrypted Client Cache:**
- Namespace: `vso`
- Transit engine: `vso-transit`
- Key: `vso-client-cache`
- Auth role: `auth-role-operator`

## Common Tasks

### Installation and Setup

```bash
# Complete installation
task install

# Install Vault only
task install:vault

# Install VSO only
task install:vso

# Configure Vault
task config:vault

# Deploy all secret types
task secrets
```

### Verification

```bash
# Verify all components
task verify

# Check pod status
task verify:pods

# Verify static secrets
task verify:static-secret

# Verify dynamic secrets
task verify:dynamic-secret

# Verify CSI integration
task verify:csi-secret
```

### Debugging

```bash
# Check Vault status
task status

# View Vault logs
task logs

# View VSO logs
task logs:vso

# Port forward Vault UI
task port-forward

# Open Vault UI with root token
task ui

# Check Kubernetes auth configuration
task list:k8s-auth

# View events
task events
```

### Cleanup

```bash
# Uninstall VSO and Vault
task uninstall

# Delete only application namespaces
task clean:namespaces

# Destroy Minikube cluster
task clean

# Destroy EKS cluster (automated)
task eks:destroy:auto

# Destroy GKE cluster (automated)
task gke:destroy:auto
```

## Verification Commands

### Check Pod Health

```bash
# All pods across all namespaces
kubectl get pods -A

# Specific namespace
kubectl get pods -n vault
kubectl get pods -n vault-secrets-operator
kubectl get pods -n static-app
kubectl get pods -n dynamic-app
kubectl get pods -n csi-app
```

### Check Vault Resources

```bash
# VaultStaticSecret resources
kubectl get vaultstaticsecret -A
kubectl describe vaultstaticsecret vault-kv-app -n static-app

# VaultDynamicSecret resources
kubectl get vaultdynamicsecret -A
kubectl describe vaultdynamicsecret vso-db-demo -n dynamic-app

# VaultAuth resources
kubectl get vaultauth -A

# VaultConnection resources
kubectl get vaultconnection -A
```

### Check Synced Secrets

```bash
# Static secrets
kubectl get secret secretkv -n static-app
kubectl describe secret secretkv -n static-app

# Dynamic secrets
kubectl get secret vso-db-demo -n dynamic-app
kubectl get secret vso-pki-demo -n dynamic-app
```

### View Application Logs

```bash
# Static app
kubectl logs -n static-app -l app=static-app

# Dynamic app
kubectl logs -n dynamic-app -l app=dynamic-app

# CSI app
kubectl logs -n csi-app -l app=csi-app
```

## Troubleshooting

### Pod Issues

```bash
# Check pod status
kubectl get pods -A

# Describe problematic pod
kubectl describe pod <pod-name> -n <namespace>

# Check logs
kubectl logs <pod-name> -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```


### VSO Issues

```bash
# Check operator logs
task logs:vso

# Verify VaultConnection
kubectl get vaultconnection -A
kubectl describe vaultconnection -n <namespace>

# Verify VaultAuth
kubectl get vaultauth -A
kubectl describe vaultauth -n <namespace>

# Verify secret sync
kubectl describe vaultstaticsecret <name> -n <namespace>
kubectl describe vaultdynamicsecret <name> -n <namespace>
```

### Common Problems

**Pods not starting:**
- Check events: `kubectl get events -A --sort-by='.lastTimestamp'`
- Verify PVC status: `kubectl get pvc -A`
- Check node resources: `kubectl top nodes`

**Secrets not syncing:**
- Verify VaultAuth status: `kubectl describe vaultauth -n <namespace>`
- Check VSO logs: `task logs:vso`
- Verify Vault policies: `task list:k8s-auth`

**CSI secrets not mounting:**
- Check CSI provider logs: `kubectl logs -n vault -l app.kubernetes.io/name=vault-csi-provider`
- Verify CSI node driver: `kubectl get pods -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator-csi`

## Environment Configuration

The project uses a `.env` file for sensitive configuration:

```bash
VAULT_TOKEN=<root-token>
```

This file is automatically created and populated by `task init:vault`.

## Additional Notes

- All Vault initialization keys are stored in `vault-init.json`
- Root token is automatically added to `.env` file
- JWT token reviewer uses long-lived service account token for cluster persistence
- Rotate secrets regularly using `task rotate:static-secret`

## License

This project is provided as-is for educational purposes.

## Resources

- [Vault Secrets Operator Documentation](https://developer.hashicorp.com/vault/docs/platform/k8s/vso)
- [Vault Kubernetes Auth Method](https://developer.hashicorp.com/vault/docs/auth/kubernetes)
- [Vault CSI Provider](https://developer.hashicorp.com/vault/docs/platform/k8s/csi)
- [HashiCorp Developer Tutorials](https://developer.hashicorp.com/vault/tutorials/kubernetes)