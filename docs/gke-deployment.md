# Google GKE Deployment Guide

## Overview

This guide provides detailed instructions for deploying HashiCorp Vault and Vault Secrets Operator (VSO) on Google Kubernetes Engine (GKE). The deployment includes complete infrastructure provisioning using Terraform and automated configuration workflows.

## Prerequisites

### Required Tools and Versions

| Tool | Minimum Version | Installation |
|------|----------------|--------------|
| gcloud CLI | 450.0+ | [Install Guide](https://cloud.google.com/sdk/docs/install) |
| kubectl | 1.24+ | [Install Guide](https://kubernetes.io/docs/tasks/tools/) |
| helm | 3.10+ | [Install Guide](https://helm.sh/docs/intro/install/) |
| terraform | 1.6+ | [Install Guide](https://developer.hashicorp.com/terraform/install) |
| task | 3.30+ | [Install Guide](https://taskfile.dev/installation/) |
| jq | 1.6+ | [Install Guide](https://jqlang.github.io/jq/download/) |

### GCP Project Requirements

**Required APIs:**
- Kubernetes Engine API (container.googleapis.com)
- Compute Engine API (compute.googleapis.com)
- Cloud Resource Manager API (cloudresourcemanager.googleapis.com)
- IAM Service Account Credentials API (iamcredentials.googleapis.com)
- Service Networking API (servicenetworking.googleapis.com)

**IAM Permissions Required:**
- Kubernetes Engine Admin
- Compute Network Admin
- Service Account Admin
- Project IAM Admin
- Security Admin

**Resource Quotas:**
- CPUs: At least 8 available
- In-use IP addresses: At least 10 available
- Persistent Disk SSD (GB): At least 100 GB available

### gcloud CLI Configuration

```bash
# Initialize gcloud
gcloud init

# Or configure manually
gcloud config set project YOUR_PROJECT_ID
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-a

# Authenticate
gcloud auth login
gcloud auth application-default login

# Verify configuration
gcloud config list
gcloud projects describe YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com
gcloud services enable compute.googleapis.com
gcloud services enable cloudresourcemanager.googleapis.com
gcloud services enable iamcredentials.googleapis.com
gcloud services enable servicenetworking.googleapis.com
```

### Vault Enterprise License

Place your Vault Enterprise license file in the `vault-ent/` directory:

```bash
vault-ent/
└── vault-license.lic  # Required: Vault Enterprise license file
```

## Infrastructure Architecture

### Network Architecture

**VPC Configuration:**
- Network: Custom VPC (auto-mode disabled)
- Subnet: us-central1 (10.0.0.0/24)
- Secondary Ranges:
  - Pods: 10.1.0.0/16
  - Services: 10.2.0.0/16
- Private Google Access: Enabled
- Cloud NAT: Enabled for private node internet access

**Firewall Rules:**
- Allow internal communication within VPC
- Allow health checks from Google Cloud load balancers
- Deny all external SSH by default
- Allow HTTPS/HTTP from authorized networks (optional)

### GKE Cluster Configuration

**Cluster Type:** Regional (High Availability)
- Region: us-central1
- Zones: us-central1-a, us-central1-b, us-central1-c
- Control Plane: Multi-zonal (GCP managed)

**Cluster Features:**
- VPC-Native Cluster: Enabled (uses alias IP ranges)
- Private Cluster: Nodes have private IPs only
- Master Authorized Networks: Configurable
- Workload Identity: Enabled (recommended for production)
- Binary Authorization: Optional
- Network Policy: Enabled (Calico)
- Vertical Pod Autoscaling: Enabled
- Horizontal Pod Autoscaling: Enabled

**Cluster Logging and Monitoring:**
- Cloud Logging: Enabled (SYSTEM, WORKLOAD)
- Cloud Monitoring: Enabled
- Managed Prometheus: Optional

**Node Pools:**

**Default Node Pool:**
- Machine Type: e2-medium (2 vCPU, 4 GB memory)
- Node Count: 3 (one per zone)
- Disk Type: pd-standard
- Disk Size: 50 GB
- Auto-scaling: Enabled (min: 3, max: 9)
- Auto-repair: Enabled
- Auto-upgrade: Enabled
- Preemptible: No (use for cost savings in dev)
- Labels: `role=default`
- Taints: None

### Storage Configuration

**Persistent Disk CSI Driver:**
- Automatically enabled in GKE
- Version: Latest stable
- Storage Classes:
  - `standard-rwo`: Standard persistent disk (default)
  - `premium-rwo`: SSD persistent disk
  - `standard`: Legacy (deprecated)

**Vault Storage:**
- Storage Class: `standard-rwo` (cluster default)
- Volume Size: 10 GB per Vault pod
- Reclaim Policy: Retain
- Volume Binding Mode: WaitForFirstConsumer
- Disk Type: pd-standard (can be changed to pd-ssd for better performance)

### Load Balancer Configuration

**GKE Ingress Controller:**
- Type: GCE L7 Load Balancer (HTTP/HTTPS)
- Backend: NEG (Network Endpoint Groups)
- Health Checks: Automatic
- SSL Certificates: Google-managed or self-managed

**Vault Service:**
- Type: LoadBalancer
- Load Balancer Type: TCP/UDP (L4)
- Internal or External: External (configurable)
- Ports: 8200 (API), 8201 (cluster)

## Deployment Steps

### Step 1: Verify Prerequisites

```bash
# Check tool versions
task prerequisites

# Expected output:
# ✓ gcloud CLI version 4xx.x.x
# ✓ kubectl version 1.x.x
# ✓ helm version 3.x.x
# ✓ terraform version 1.x.x
# ✓ task version 3.x.x
# ✓ jq version 1.x.x

# Verify GCP authentication
gcloud auth list
gcloud config get-value project
```

### Step 2: Deploy GKE Infrastructure

```bash
# Navigate to GKE directory
cd gke/

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure (10-15 minutes)
terraform apply

# Or use the automated task
cd ..
task gke:all
```

**What Gets Created:**
- Custom VPC network with subnet
- Cloud NAT for private node internet access
- GKE regional cluster with control plane
- Default node pool with 3 nodes
- Firewall rules
- Service accounts
- IAM bindings
- Cloud Logging and Monitoring configuration

### Step 3: Configure kubectl

```bash
# Get cluster credentials
gcloud container clusters get-credentials vault-gke-cluster --region us-central1

# Verify cluster access
kubectl get nodes

# Expected output:
# NAME                                                  STATUS   ROLES    AGE   VERSION
# gke-vault-gke-cluster-default-pool-xxxxxxxx-xxxx     Ready    <none>   5m    v1.28.x
# gke-vault-gke-cluster-default-pool-xxxxxxxx-xxxx     Ready    <none>   5m    v1.28.x
# gke-vault-gke-cluster-default-pool-xxxxxxxx-xxxx     Ready    <none>   5m    v1.28.x

# Verify cluster info
kubectl cluster-info

# Check storage classes
kubectl get storageclass

# Expected output:
# NAME                     PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
# premium-rwo              pd.csi.storage.gke.io   Delete          WaitForFirstConsumer   true                   5m
# standard (default)       kubernetes.io/gce-pd    Delete          Immediate              true                   5m
# standard-rwo (default)   pd.csi.storage.gke.io   Delete          WaitForFirstConsumer   true                   5m
```

### Step 4: Install Vault and VSO

```bash
# Install Vault (uses cluster default storage class)
task install:vault

# Verify Vault installation
kubectl get pods -n vault

# Expected output:
# NAME                                    READY   STATUS    RESTARTS   AGE
# vault-0                                 1/1     Running   0          2m
# vault-agent-injector-xxxxxxxxxx-xxxxx   1/1     Running   0          2m

# Check Vault PVC
kubectl get pvc -n vault

# Expected output:
# NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# data-vault-0   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   10Gi       RWO            standard-rwo   2m

# Install VSO
task install:vso

# Verify VSO installation
kubectl get pods -n vault-secrets-operator
```

### Step 5: Configure Vault

```bash
# Initialize and configure Vault
task config:vault

# This performs:
# - Vault initialization
# - Unsealing
# - Root token configuration
# - Namespace creation (vso, tn001)
# - Secret engine setup (KV, Database, PKI, Transit)
# - Kubernetes auth configuration
# - Policy creation
# - Role configuration
```

### Step 6: Deploy Secrets

```bash
# Deploy all secret types
task secrets

# This creates:
# - Static secret applications (static-app-1, static-app-2, static-app-3)
# - Dynamic secret application (dynamic-app)
# - CSI secret application (csi-app)
# - PostgreSQL database for dynamic secrets
```

### Step 7: Verify Deployment

```bash
# Run complete verification
task verify

# Individual verifications
task verify:pods          # Check all pod status
task verify:static-secret # Verify static secret sync
task verify:dynamic-secret # Verify dynamic secret generation
task verify:csi-secret    # Verify CSI volume mounts

# Check Vault service external IP
kubectl get svc -n vault vault

# Expected output:
# NAME    TYPE           CLUSTER-IP      EXTERNAL-IP      PORT(S)
# vault   LoadBalancer   10.x.x.x        xx.xx.xx.xx      8200:xxxxx/TCP,8201:xxxxx/TCP
```

## Troubleshooting

### Common Issues

#### 1. Cluster Creation Fails

**Symptom:** Terraform apply fails during GKE cluster creation

**Possible Causes:**
- Insufficient IAM permissions
- API not enabled
- Resource quota exceeded
- Invalid network configuration

**Solution:**
```bash
# Check IAM permissions
gcloud projects get-iam-policy YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable container.googleapis.com compute.googleapis.com

# Check quotas
gcloud compute project-info describe --project=YOUR_PROJECT_ID

# Review Terraform logs
terraform apply -debug

# Clean up and retry
terraform destroy
terraform apply
```

#### 2. Nodes Not Ready

**Symptom:** Nodes show as NotReady or don't appear

**Possible Causes:**
- Network connectivity issues
- Insufficient resources
- Node pool configuration errors

**Solution:**
```bash
# Check node status
kubectl get nodes

# Describe node for events
kubectl describe node <node-name>

# Check node pool status
gcloud container node-pools describe default-pool \
  --cluster=vault-gke-cluster \
  --region=us-central1

# View node pool events
gcloud logging read "resource.type=gke_nodepool AND resource.labels.cluster_name=vault-gke-cluster" \
  --limit 50 \
  --format json
```

#### 3. PVC Stuck in Pending

**Symptom:** PVCs stuck in Pending state

**Possible Causes:**
- Storage class not available
- Insufficient disk quota
- Zone mismatch

**Solution:**
```bash
# Check PVC status
kubectl get pvc -A

# Describe PVC for events
kubectl describe pvc <pvc-name> -n <namespace>

# Check storage classes
kubectl get storageclass

# Verify disk quota
gcloud compute project-info describe --project=YOUR_PROJECT_ID | grep -A 5 "DISKS_TOTAL_GB"

# Check available zones
gcloud compute zones list --filter="region:us-central1"

# Manually create test PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: standard-rwo
  resources:
    requests:
      storage: 1Gi
EOF

kubectl get pvc test-pvc
```

#### 4. Load Balancer Not Provisioning

**Symptom:** Vault service stuck in Pending, no EXTERNAL-IP

**Possible Causes:**
- Insufficient IP address quota
- Firewall rules blocking health checks
- Service configuration errors

**Solution:**
```bash
# Check service status
kubectl get svc -n vault vault

# Describe service for events
kubectl describe svc vault -n vault

# Check IP address quota
gcloud compute project-info describe --project=YOUR_PROJECT_ID | grep -A 5 "IN_USE_ADDRESSES"

# Check firewall rules
gcloud compute firewall-rules list

# Verify health check firewall rule exists
gcloud compute firewall-rules describe allow-health-checks

# Check load balancer status
gcloud compute forwarding-rules list
gcloud compute target-pools list
```

#### 5. Vault Pods Not Starting

**Symptom:** Vault pods in CrashLoopBackOff or Pending

**Possible Causes:**
- PVC not bound
- Insufficient node resources
- License file missing
- Image pull errors

**Solution:**
```bash
# Check pod status
kubectl get pods -n vault

# Describe pod for events
kubectl describe pod vault-0 -n vault

# Check PVC status
kubectl get pvc -n vault

# Check node resources
kubectl top nodes

# Verify license file
ls -la vault-ent/vault-license.lic

# Check Vault logs
kubectl logs vault-0 -n vault

# Check image pull status
kubectl get events -n vault --sort-by='.lastTimestamp' | grep -i pull
```

#### 6. Workload Identity Issues

**Symptom:** Pods cannot access GCP services

**Possible Causes:**
- Workload Identity not properly configured
- IAM bindings missing
- Service account annotation missing

**Solution:**
```bash
# Verify Workload Identity is enabled
gcloud container clusters describe vault-gke-cluster --region us-central1 --format="value(workloadIdentityConfig.workloadPool)"

# Check Kubernetes service account annotation
kubectl get sa vault -n vault -o yaml | grep iam.gke.io/gcp-service-account

# Verify IAM binding
gcloud iam service-accounts get-iam-policy vault-gke-sa@YOUR_PROJECT_ID.iam.gserviceaccount.com

# Test from pod
kubectl run -it --rm test-wi --image=google/cloud-sdk:slim --serviceaccount=vault -n vault -- gcloud auth list
```

### Debugging Commands

```bash
# Cluster information
kubectl cluster-info
kubectl get nodes -o wide

# GKE cluster details
gcloud container clusters describe vault-gke-cluster --region us-central1

# Node pool details
gcloud container node-pools list --cluster=vault-gke-cluster --region=us-central1
gcloud container node-pools describe default-pool --cluster=vault-gke-cluster --region=us-central1

# Network details
gcloud compute networks describe vault-gke-network
gcloud compute networks subnets describe vault-gke-subnet --region=us-central1

# Firewall rules
gcloud compute firewall-rules list --filter="network:vault-gke-network"

# Cloud NAT
gcloud compute routers describe vault-gke-router --region=us-central1
gcloud compute routers nats describe vault-gke-nat --router=vault-gke-router --region=us-central1

# Load balancers
gcloud compute forwarding-rules list
gcloud compute backend-services list

# Cloud Logging
gcloud logging read "resource.type=k8s_cluster AND resource.labels.cluster_name=vault-gke-cluster" --limit 50

# Cloud Monitoring
gcloud monitoring dashboards list
```

## Cleanup

### Automated Cleanup

```bash
# Destroy all resources (automated, no confirmation)
task gke:destroy:auto

# This will:
# 1. Delete all Kubernetes resources
# 2. Destroy GKE cluster
# 3. Delete VPC network and subnets
# 4. Remove Cloud NAT and router
# 5. Delete firewall rules
# 6. Remove service accounts and IAM bindings
```

### Manual Cleanup

```bash
# Step 1: Delete Kubernetes resources
task uninstall

# Step 2: Delete GKE infrastructure
cd gke/
terraform destroy
```

## Additional Resources

- [GKE Best Practices](https://cloud.google.com/kubernetes-engine/docs/best-practices)
- [GKE Security Hardening Guide](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster)
- [Workload Identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [GKE Networking](https://cloud.google.com/kubernetes-engine/docs/concepts/network-overview)
- [Vault on GKE](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-google-cloud-gke)
- [GKE Cost Optimization](https://cloud.google.com/architecture/best-practices-for-running-cost-effective-kubernetes-applications-on-gke)
