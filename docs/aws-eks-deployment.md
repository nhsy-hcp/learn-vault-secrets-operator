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
# Check tool versions
task prerequisites

# Expected output:
# ✓ AWS CLI version 2.x.x
# ✓ kubectl version 1.x.x
# ✓ helm version 3.x.x
# ✓ terraform version 1.x.x
# ✓ task version 3.x.x
# ✓ jq version 1.x.x
```

### Step 2: Deploy EKS Infrastructure

```bash
# Navigate to EKS directory
cd eks/

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Deploy infrastructure (15-20 minutes)
terraform apply

# Or use the automated task
cd ..
task eks:all
```

**What Gets Created:**
- VPC with public and private subnets
- Internet Gateway and NAT Gateways
- EKS cluster with control plane
- Two managed node groups
- EBS CSI driver add-on
- AWS Load Balancer Controller
- IAM roles and policies
- Security groups
- CloudWatch log groups

### Step 3: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-west-2 --name vault-eks-cluster

# Verify cluster access
kubectl get nodes

# Expected output:
# NAME                                       STATUS   ROLES    AGE   VERSION
# ip-10-0-1-xxx.us-west-2.compute.internal   Ready    <none>   5m    v1.28.x
# ip-10-0-2-xxx.us-west-2.compute.internal   Ready    <none>   5m    v1.28.x
# ip-10-0-3-xxx.us-west-2.compute.internal   Ready    <none>   5m    v1.28.x
# ip-10-0-4-xxx.us-west-2.compute.internal   Ready    <none>   5m    v1.28.x

# Verify EBS CSI driver
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# Verify AWS Load Balancer Controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller
```

### Step 4: Install Vault and VSO

```bash
# Install Vault with EKS-specific storage class
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
# data-vault-0   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   10Gi       RWO            gp2            2m

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
# NAME    TYPE           CLUSTER-IP      EXTERNAL-IP                                                              PORT(S)
# vault   LoadBalancer   10.100.xxx.xxx  xxxxx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.elb.us-west-2.amazonaws.com      8200:xxxxx/TCP,8201:xxxxx/TCP
```

## Troubleshooting

### Common Issues

#### 1. Cluster Creation Fails

**Symptom:** Terraform apply fails during EKS cluster creation

**Possible Causes:**
- Insufficient IAM permissions
- Service quota limits reached
- Invalid VPC configuration

**Solution:**
```bash
# Check IAM permissions
aws iam get-user

# Check service quotas
aws service-quotas list-service-quotas --service-code eks

# Review Terraform logs
terraform apply -debug

# Clean up and retry
terraform destroy
terraform apply
```

#### 2. Nodes Not Joining Cluster

**Symptom:** Nodes show as NotReady or don't appear

**Possible Causes:**
- Security group misconfiguration
- IAM role issues
- Subnet routing problems

**Solution:**
```bash
# Check node status
kubectl get nodes

# Describe node for events
kubectl describe node <node-name>

# Check node group status
aws eks describe-nodegroup --cluster-name vault-eks-cluster --nodegroup-name system-nodes

# View node group logs
aws eks describe-nodegroup --cluster-name vault-eks-cluster --nodegroup-name system-nodes --query 'nodegroup.health'
```

#### 3. EBS CSI Driver Issues

**Symptom:** PVCs stuck in Pending state

**Possible Causes:**
- EBS CSI driver not installed
- IAM role misconfiguration
- Storage class issues

**Solution:**
```bash
# Check EBS CSI driver pods
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# Check CSI driver logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-ebs-csi-driver

# Verify IAM role
kubectl describe sa ebs-csi-controller-sa -n kube-system

# Check PVC events
kubectl describe pvc <pvc-name> -n <namespace>

# Manually create test PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp2
  resources:
    requests:
      storage: 1Gi
EOF

kubectl get pvc test-pvc
```

#### 4. Load Balancer Not Provisioning

**Symptom:** Vault service stuck in Pending, no EXTERNAL-IP

**Possible Causes:**
- AWS Load Balancer Controller not installed
- IAM role issues
- Subnet tagging missing

**Solution:**
```bash
# Check ALB controller
kubectl get pods -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=aws-load-balancer-controller

# Verify subnet tags
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>" --query 'Subnets[*].[SubnetId,Tags]'

# Required tags:
# Public subnets: kubernetes.io/role/elb=1
# Private subnets: kubernetes.io/role/internal-elb=1

# Check service events
kubectl describe svc vault -n vault
```

#### 5. Vault Pods Not Starting

**Symptom:** Vault pods in CrashLoopBackOff or Pending

**Possible Causes:**
- PVC not bound
- Insufficient node resources
- License file missing

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
```

### Debugging Commands

```bash
# Cluster information
kubectl cluster-info
kubectl get nodes -o wide

# EKS cluster details
aws eks describe-cluster --name vault-eks-cluster

# Node group details
aws eks list-nodegroups --cluster-name vault-eks-cluster
aws eks describe-nodegroup --cluster-name vault-eks-cluster --nodegroup-name system-nodes

# VPC and networking
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=vault-eks-vpc"
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>"
aws ec2 describe-nat-gateways --filter "Name=vpc-id,Values=<vpc-id>"

# Security groups
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=<vpc-id>"

# Load balancers
aws elbv2 describe-load-balancers
aws elbv2 describe-target-groups

# CloudWatch logs
aws logs describe-log-groups --log-group-name-prefix /aws/eks/vault-eks-cluster

# IAM roles
aws iam list-roles --query 'Roles[?contains(RoleName, `eks`) || contains(RoleName, `EBS`) || contains(RoleName, `LoadBalancer`)]'
```

## Cleanup

### Automated Cleanup

```bash
# Destroy all resources (automated, no confirmation)
task eks:destroy:auto

# This will:
# 1. Delete all Kubernetes resources
# 2. Destroy EKS cluster
# 3. Delete VPC and networking
# 4. Remove IAM roles and policies
# 5. Delete CloudWatch log groups
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
