# Amazon EKS Deployment Guide

## Overview

This guide provides detailed instructions for deploying HashiCorp Vault and Vault Secrets Operator (VSO) on Amazon Elastic Kubernetes Service (EKS). The deployment includes complete infrastructure provisioning using Terraform and automated configuration workflows.

## Prerequisites

### Required Tools and Versions

| Tool | Minimum Version | Installation |
|------|----------------|--------------|
| AWS CLI | 2.13+ | [Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| kubectl | 1.24+ | [Install Guide](https://kubernetes.io/docs/tasks/tools/) |
| helm | 3.10+ | [Install Guide](https://helm.sh/docs/intro/install/) |
| terraform | 1.6+ | [Install Guide](https://developer.hashicorp.com/terraform/install) |
| task | 3.30+ | [Install Guide](https://taskfile.dev/installation/) |
| jq | 1.6+ | [Install Guide](https://jqlang.github.io/jq/download/) |
| k9s | 0.27+ (optional) | [Install Guide](https://k9scli.io/topics/install/) |

### AWS Account Requirements

**IAM Permissions Required:**
- EKS cluster creation and management
- VPC and networking resources (subnets, route tables, NAT gateways)
- EC2 instances and Auto Scaling groups
- Elastic Load Balancing (ALB/NLB)
- IAM roles and policies
- CloudWatch logs
- Systems Manager (for EKS add-ons)

**Service Quotas:**
- VPCs: At least 1 available
- Elastic IPs: At least 2 available (for NAT gateways)
- EC2 instances: Sufficient quota for node groups
- EBS volumes: Sufficient quota for persistent storage

### AWS CLI Configuration

```bash
# Configure AWS credentials
aws configure

# Or use environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-west-2"

# Or use AWS profiles
export AWS_PROFILE="your-profile-name"

# Verify configuration
aws sts get-caller-identity
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
- CIDR: 10.0.0.0/16
- Availability Zones: 2 (us-west-2a, us-west-2b)
- Public Subnets: 2 (10.0.1.0/24, 10.0.2.0/24)
- Private Subnets: 2 (10.0.3.0/24, 10.0.4.0/24)
- NAT Gateways: 2 (one per AZ for high availability)
- Internet Gateway: 1

**Subnet Strategy:**
- Public subnets: Load balancers, bastion hosts
- Private subnets: EKS worker nodes, application pods
- Automatic subnet tagging for EKS discovery

### EKS Cluster Configuration

**Control Plane:**
- Kubernetes Version: 1.28
- Endpoint: Public and private access
- Cluster Logging: API server, audit, authenticator, controller manager, scheduler
- Encryption: Secrets encrypted at rest using AWS KMS

**Node Groups:**

**System Node Group:**
- Instance Type: t3.medium
- Desired Capacity: 2
- Min Size: 2
- Max Size: 4
- Disk Size: 50 GB (gp3)
- Labels: `role=system`
- Taints: None
- Purpose: System components (CoreDNS, kube-proxy, VSO, Vault)

**Application Node Group:**
- Instance Type: t3.medium
- Desired Capacity: 2
- Min Size: 2
- Max Size: 6
- Disk Size: 50 GB (gp3)
- Labels: `role=application`
- Taints: None
- Purpose: Application workloads

### Storage Configuration

**EBS CSI Driver:**
- Automatically installed via EKS add-on
- Version: Latest stable
- IAM Role: Automatically configured with IRSA
- Storage Classes:
  - `gp2`: General Purpose SSD (default for Vault)
  - `gp3`: General Purpose SSD (newer, more cost-effective)
  - `io1`: Provisioned IOPS SSD (high performance)

**Vault Storage:**
- Storage Class: `gp2`
- Volume Size: 10 GB per Vault pod
- Reclaim Policy: Retain
- Volume Binding Mode: WaitForFirstConsumer

### Load Balancer Configuration

**AWS Load Balancer Controller:**
- Automatically installed
- Version: Latest stable
- IAM Role: Configured with IRSA
- Supports: ALB (Application Load Balancer) and NLB (Network Load Balancer)

**Vault Service:**
- Type: LoadBalancer
- Annotations: `service.beta.kubernetes.io/aws-load-balancer-type: nlb`
- Ports: 8200 (API), 8201 (cluster)

## Deployment Steps

### Step 1: Verify Prerequisites

```bash
# Check tool versions and AWS configuration
task prerequisites
```

### Step 2: Deploy EKS Infrastructure

```bash
# Deploy complete EKS infrastructure (25+ minutes)
task eks:all

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
# Get root token and open UI
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

### Common Issues

#### 0. kubectl Access Issues

**Symptom:** kubectl commands fail with connection errors or "Unable to connect to the server"

**Solution:**
```bash
# Refresh kubectl credentials
task eks:eks-credentials

# Verify cluster access
kubectl cluster-info

# Check current context
kubectl config current-context

# Manually update kubeconfig if needed
aws eks update-kubeconfig --name eks-hcp --region eu-west-1
```

#### 1. Cluster Creation Fails

**Symptom:** Terraform apply fails during EKS cluster creation

**Solution:**
```bash
# Check IAM permissions
aws iam get-user

# Check service quotas
aws service-quotas list-service-quotas --service-code eks

# Clean up and retry
cd eks/
terraform destroy
terraform apply
```

#### 2. Nodes Not Joining Cluster

**Symptom:** Nodes show as NotReady or don't appear

**Solution:**
```bash
# Check node status
kubectl get nodes

# Check node group status
aws eks describe-nodegroup --cluster-name eks-hcp --nodegroup-name system-nodes
```

#### 3. EBS CSI Driver Issues

**Symptom:** PVCs stuck in Pending state

**Solution:**
```bash
# Check EBS CSI driver pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# Check CSI driver logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# Check PVC events
kubectl describe pvc <pvc-name> -n <namespace>
```

#### 4. Load Balancer Not Provisioning

**Symptom:** Vault service stuck in Pending, no EXTERNAL-IP

**Solution:**
```bash
# Check ALB controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check service events
kubectl describe svc vault -n vault
```

#### 5. Vault Pods Not Starting

**Symptom:** Vault pods in CrashLoopBackOff or Pending

**Solution:**
```bash
# Check pod status
kubectl get pods -n vault

# Describe pod for events
kubectl describe pod vault-0 -n vault

# Check PVC status
kubectl get pvc -n vault

# Verify license file
ls -la vault-ent/vault-license.lic

# Check Vault logs
kubectl logs vault-0 -n vault
```

#### 6. Secret Synchronization Issues

**Symptom:** VaultStaticSecret or VaultDynamicSecret not syncing

**Solution:**
```bash
# Check VSO logs
task logs:vso

# Verify VaultConnection
kubectl get vaultconnection -A

# Verify VaultAuth
kubectl get vaultauth -A

# Describe VaultStaticSecret
kubectl describe vaultstaticsecret -n static-app-1

# Check Vault auth configuration
task list:k8s-auth
```

### Debugging Commands

```bash
# Cluster information
kubectl cluster-info
kubectl get nodes -o wide

# EKS cluster details
aws eks describe-cluster --name eks-hcp

# Node group details
aws eks list-nodegroups --cluster-name eks-hcp
aws eks describe-nodegroup --cluster-name eks-hcp --nodegroup-name system-nodes

# Check all events
kubectl get events -A --sort-by='.lastTimestamp'

# Or use k9s for interactive exploration
k9s
```

## Cleanup

### Automated Cleanup

```bash
# Destroy all resources (20+ minutes)
task eks:destroy:auto

# Wait 3 minutes for asynchronous deletions
sleep 180

# Verify cluster is destroyed
aws eks describe-cluster --name eks-hcp --region eu-west-1
# Expected: ResourceNotFoundException
```

### Manual Cleanup

```bash
# Step 1: Delete Kubernetes resources
task uninstall

# Step 2: Delete EKS infrastructure
cd eks/
terraform destroy
```

## Additional Resources

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [EKS Workshop](https://www.eksworkshop.com/)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
- [Vault on EKS](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-amazon-eks)
- [k9s Documentation](https://k9scli.io/)
