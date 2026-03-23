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
| k9s | 0.27+ (optional) | [Install Guide](https://k9scli.io/topics/install/) |

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
gcloud config set compute/region europe-west1
gcloud config set compute/zone europe-west1-b

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
- Subnet: europe-west1 (10.0.0.0/24)
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
- Region: europe-west1
- Zones: europe-west1-b, europe-west1-c, europe-west1-d
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
# Check tool versions and GCP configuration
task prerequisites
```

### Step 2: Deploy GKE Infrastructure

```bash
# Deploy complete GKE infrastructure (20+ minutes)
task gke:all

# Wait 3 minutes for stabilization
sleep 180

# Verify cluster connectivity
kubectl cluster-info

# Open k9s for interactive cluster exploration
k9s
```

### Step 3: Install Vault and VSO

```bash
# Install and configure Vault and VSO
task install

# Wait for pods to stabilize
kubectl get pods -n vault
kubectl get pods -n vault-secrets-operator
```

### Step 4: Deploy Secret Applications

```bash
# Deploy all secret types and applications
task secrets
```

### Step 5: Verify Complete Deployment

```bash
# Run comprehensive verification
task verify
```

## Monitoring with k9s

k9s provides a terminal-based UI for managing Kubernetes clusters:

```bash
# Launch k9s
k9s

# Useful k9s commands:
# :pods          - View all pods
# :ns            - Switch namespace
# :vault         - Jump to vault namespace
# :events        - View cluster events
# :pvc           - View persistent volume claims
# :svc           - View services
# /              - Filter resources
# l              - View logs
# d              - Describe resource
# Ctrl+d         - Delete resource
# ?              - Help
```

## Post-Deployment Operations

### Accessing Vault UI

```bash
# In a separate terminal window, start port forwarding
task port-forward

# In your main terminal, get root token and open UI
task ui
```

### Secret Rotation

```bash
# Rotate static secrets
task rotate:static-secret

# Rotate dynamic database secrets
task rotate:dynamic-secret

# Rotate CSI secrets
task rotate:csi:secret
```

### Monitoring and Debugging

```bash
# View Vault logs
task logs

# View VSO logs
task logs:vso

# Check Kubernetes events
task events

# Port forward Vault for local access
task port-forward

# List Kubernetes auth configuration
task list:k8s-auth

# List identity entities
task list:identity-entities
```

## Troubleshooting

For detailed troubleshooting procedures, common issues, and platform-specific solutions, refer to the [Troubleshooting Guide](troubleshooting.md).

**Quick kubectl Access Fix:**
```bash
# Refresh kubectl credentials
task gke:credentials

# Verify cluster access
kubectl cluster-info
```

## Cleanup

### Automated Cleanup

```bash
# Destroy all resources (15+ minutes)
task gke:destroy:auto

# Wait 3 minutes for asynchronous deletions
sleep 180

# Verify cluster is destroyed
gcloud container clusters describe gke-hcp --region europe-west1
# Expected: ERROR: (gcloud.container.clusters.describe) ResponseError: code=404
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
- [k9s Documentation](https://k9scli.io/)
