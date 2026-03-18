# Minikube Local Development Guide

## Overview

This guide provides detailed instructions for deploying HashiCorp Vault and Vault Secrets Operator (VSO) on Minikube for local development and testing. Minikube provides a lightweight, single-node Kubernetes cluster ideal for learning and development workflows.

## Prerequisites

### Required Tools and Versions

| Tool | Minimum Version | Installation |
|------|----------------|--------------|
| minikube | 1.30+ | [Install Guide](https://minikube.sigs.k8s.io/docs/start/) |
| kubectl | 1.24+ | [Install Guide](https://kubernetes.io/docs/tasks/tools/) |
| helm | 3.10+ | [Install Guide](https://helm.sh/docs/intro/install/) |
| task | 3.30+ | [Install Guide](https://taskfile.dev/installation/) |
| jq | 1.6+ | [Install Guide](https://jqlang.github.io/jq/download/) |
| Docker | 20.10+ | [Install Guide](https://docs.docker.com/get-docker/) |

### System Requirements

**Minimum:**
- CPU: 2 cores
- Memory: 4 GB RAM
- Disk: 20 GB free space
- Virtualization: Enabled in BIOS

**Recommended:**
- CPU: 4 cores
- Memory: 8 GB RAM
- Disk: 40 GB free space
- SSD storage for better performance

### Hypervisor Options

Minikube supports multiple drivers (hypervisors):

**macOS:**
- Docker (recommended) - Uses Docker Desktop
- HyperKit - Native macOS hypervisor
- VirtualBox - Cross-platform
- Parallels - Commercial option
- VMware Fusion - Commercial option

**Linux:**
- Docker (recommended) - Uses Docker Engine
- KVM2 - Native Linux hypervisor
- VirtualBox - Cross-platform
- Podman - Rootless container runtime

**Windows:**
- Docker (recommended) - Uses Docker Desktop
- Hyper-V - Native Windows hypervisor
- VirtualBox - Cross-platform
- VMware Workstation - Commercial option

### Vault Enterprise License

Place your Vault Enterprise license file in the `vault-ent/` directory:

```bash
vault-ent/
└── vault-license.lic  # Required: Vault Enterprise license file
```

## Minikube Architecture

### Single-Node Cluster

**Characteristics:**
- Control plane and worker node combined
- Runs in a VM or container
- Local storage provisioner
- Simple networking (no cloud load balancers)
- Ideal for development and testing

**Components:**
- Kubernetes control plane (API server, scheduler, controller manager)
- etcd (key-value store)
- Container runtime (Docker, containerd, or CRI-O)
- kubelet (node agent)
- kube-proxy (network proxy)

### Storage

**Storage Provisioner:**
- Type: `k8s.io/minikube-hostpath`
- Storage Class: `standard` (default)
- Volume Type: Host path on minikube VM/container
- Persistence: Survives pod restarts, not cluster deletion
- Performance: Depends on host disk performance

**Vault Storage:**
- Storage Class: `standard`
- Volume Size: 10 GB per Vault pod
- Reclaim Policy: Delete (default)
- Volume Binding Mode: Immediate

### Networking

**Service Types:**
- ClusterIP: Internal cluster access only
- NodePort: Access via minikube IP and node port
- LoadBalancer: Minikube tunnel provides external IP

**Ingress:**
- Minikube ingress addon (nginx-based)
- Enables HTTP/HTTPS routing
- Requires `minikube tunnel` for external access

**DNS:**
- CoreDNS for internal service discovery
- Automatic DNS resolution for services

## Deployment Steps

### Step 1: Verify Prerequisites

```bash
# Check tool versions
task prerequisites

# Expected output:
# ✓ minikube version 1.x.x
# ✓ kubectl version 1.x.x
# ✓ helm version 3.x.x
# ✓ task version 3.x.x
# ✓ jq version 1.x.x

# Verify Docker is running (if using Docker driver)
docker ps

# Check virtualization support (Linux)
egrep -q 'vmx|svm' /proc/cpuinfo && echo "Virtualization supported" || echo "Virtualization not supported"

# Check virtualization support (macOS)
sysctl -a | grep -E --color 'machdep.cpu.features|VMX'
```

### Step 2: Start Minikube Cluster

```bash
# Start minikube with recommended settings
task minikube

# Or manually with custom settings
minikube start \
  --cpus=4 \
  --memory=8192 \
  --disk-size=40g \
  --driver=docker \
  --kubernetes-version=v1.28.0

# Verify cluster is running
minikube status

# Expected output:
# minikube
# type: Control Plane
# host: Running
# kubelet: Running
# apiserver: Running
# kubeconfig: Configured

# Verify kubectl context
kubectl config current-context
# Expected: minikube

# Check nodes
kubectl get nodes

# Expected output:
# NAME       STATUS   ROLES           AGE   VERSION
# minikube   Ready    control-plane   1m    v1.28.x
```

### Step 3: Enable Minikube Addons (Optional)

```bash
# Enable metrics-server for resource monitoring
minikube addons enable metrics-server

# Enable ingress for HTTP routing
minikube addons enable ingress

# Enable dashboard for web UI
minikube addons enable dashboard

# List all addons
minikube addons list

# Access dashboard
minikube dashboard
```

### Step 4: Install Vault and VSO

```bash
# Install Vault
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
# data-vault-0   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   10Gi       RWO            standard       2m

# Install VSO
task install:vso

# Verify VSO installation
kubectl get pods -n vault-secrets-operator

# Expected output:
# NAME                                                        READY   STATUS    RESTARTS   AGE
# vault-secrets-operator-controller-manager-xxxxxxxxx-xxxxx   2/2     Running   0          1m
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

# Verify Vault is unsealed
kubectl exec -n vault vault-0 -- vault status

# Expected output includes:
# Sealed: false
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

# Verify all namespaces
kubectl get namespaces

# Expected output includes:
# vault
# vault-secrets-operator
# static-app-1
# static-app-2
# static-app-3
# dynamic-app
# csi-app
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

# Check all pods across namespaces
kubectl get pods -A

# All pods should be in Running state
```

## Accessing Vault

### Method 1: Port Forward (Recommended)

```bash
# Port forward Vault service
task port-forward

# Or manually
kubectl port-forward -n vault svc/vault 8200:8200

# Access Vault UI
open http://localhost:8200

# Get root token
cat .env | grep VAULT_TOKEN

# Or from vault-init.json
jq -r '.root_token' vault-init.json
```

### Method 2: Minikube Service

```bash
# Get Vault service URL
minikube service vault -n vault --url

# Expected output:
# http://192.168.xx.xx:xxxxx

# Access Vault UI
open $(minikube service vault -n vault --url)
```

### Method 3: Minikube Tunnel (LoadBalancer)

```bash
# Start minikube tunnel (requires sudo/admin)
minikube tunnel

# In another terminal, get external IP
kubectl get svc -n vault vault

# Expected output:
# NAME    TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)
# vault   LoadBalancer   10.x.x.x        127.0.0.1       8200:xxxxx/TCP

# Access Vault UI
open http://127.0.0.1:8200
```

### Method 4: NodePort

```bash
# Change Vault service to NodePort
kubectl patch svc vault -n vault -p '{"spec":{"type":"NodePort"}}'

# Get minikube IP and node port
export MINIKUBE_IP=$(minikube ip)
export NODE_PORT=$(kubectl get svc vault -n vault -o jsonpath='{.spec.ports[0].nodePort}')

# Access Vault UI
open http://${MINIKUBE_IP}:${NODE_PORT}
```

## Minikube-Specific Operations

### Cluster Management

```bash
# Stop cluster (preserves state)
minikube stop

# Start stopped cluster
minikube start

# Restart cluster
minikube stop && minikube start

# Delete cluster (destroys all data)
minikube delete

# Pause cluster (saves resources)
minikube pause

# Unpause cluster
minikube unpause

# Get cluster IP
minikube ip

# SSH into minikube VM
minikube ssh
```

### Resource Management

```bash
# View cluster resource usage
kubectl top nodes
kubectl top pods -A

# Increase cluster resources (requires restart)
minikube stop
minikube start --cpus=6 --memory=12288

# View minikube logs
minikube logs

# View specific component logs
minikube logs --file=kubelet
minikube logs --file=apiserver
```

### Storage Management

```bash
# List persistent volumes
kubectl get pv

# List persistent volume claims
kubectl get pvc -A

# View storage class
kubectl get storageclass

# Access persistent volume data (via SSH)
minikube ssh
ls -la /tmp/hostpath-provisioner/

# Backup persistent volume data
minikube ssh "sudo tar czf /tmp/vault-backup.tar.gz /tmp/hostpath-provisioner/default/data-vault-0*"
minikube cp minikube:/tmp/vault-backup.tar.gz ./vault-backup.tar.gz
```

### Networking

```bash
# List services with URLs
minikube service list

# Open service in browser
minikube service vault -n vault

# Get service URL
minikube service vault -n vault --url

# Enable ingress addon
minikube addons enable ingress

# Get ingress IP
kubectl get ingress -A
```

### Addons

```bash
# List available addons
minikube addons list

# Enable addon
minikube addons enable <addon-name>

# Disable addon
minikube addons disable <addon-name>

# Useful addons for development:
minikube addons enable metrics-server    # Resource metrics
minikube addons enable dashboard         # Web UI
minikube addons enable ingress          # HTTP routing
minikube addons enable registry         # Local container registry
minikube addons enable storage-provisioner-gluster  # Alternative storage
```

## Development Workflows

### Rapid Iteration

```bash
# Quick restart after code changes
task uninstall
task install
task secrets
task verify

# Or individual components
task install:vault
task config:vault
task secrets:static
```

### Testing Different Configurations

```bash
# Test with different Vault versions
helm upgrade vault hashicorp/vault \
  --namespace vault \
  --set server.image.tag=1.15.0

# Test with different VSO versions
helm upgrade vault-secrets-operator hashicorp/vault-secrets-operator \
  --namespace vault-secrets-operator \
  --version 0.4.0

# Test with different storage classes
kubectl patch pvc data-vault-0 -n vault -p '{"spec":{"storageClassName":"standard"}}'
```

### Debugging

```bash
# View all events
kubectl get events -A --sort-by='.lastTimestamp'

# View events for specific namespace
kubectl get events -n vault --sort-by='.lastTimestamp'

# Describe resources
kubectl describe pod vault-0 -n vault
kubectl describe pvc data-vault-0 -n vault
kubectl describe vaultauth -n static-app-1

# View logs
kubectl logs -n vault vault-0
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator
kubectl logs -n static-app-1 -l app=static-app

# Follow logs
kubectl logs -n vault vault-0 -f

# Execute commands in pod
kubectl exec -n vault vault-0 -- vault status
kubectl exec -n vault vault-0 -- vault token lookup

# Port forward for debugging
kubectl port-forward -n vault vault-0 8200:8200
kubectl port-forward -n dynamic-app svc/postgres 5432:5432
```

### Local Development Tips

1. **Use Minikube Docker Daemon:**
```bash
# Point Docker CLI to minikube's Docker daemon
eval $(minikube docker-env)

# Build images directly in minikube
docker build -t my-app:latest .

# Use image in Kubernetes without pushing to registry
kubectl run my-app --image=my-app:latest --image-pull-policy=Never
```

2. **Mount Local Directories:**
```bash
# Mount local directory into minikube
minikube mount /path/to/local/dir:/path/in/minikube

# Use in pod
kubectl run test --image=busybox --command -- sleep 3600
kubectl exec test -- ls /path/in/minikube
```

3. **Use Local Registry:**
```bash
# Enable registry addon
minikube addons enable registry

# Push image to local registry
docker tag my-app:latest localhost:5000/my-app:latest
docker push localhost:5000/my-app:latest

# Use in Kubernetes
kubectl run my-app --image=localhost:5000/my-app:latest
```

## Troubleshooting

### Common Issues

#### 1. Minikube Won't Start

**Symptom:** `minikube start` fails

**Possible Causes:**
- Insufficient resources
- Virtualization not enabled
- Driver issues
- Conflicting VMs

**Solution:**
```bash
# Check minikube logs
minikube logs

# Delete and recreate cluster
minikube delete
minikube start --driver=docker

# Try different driver
minikube start --driver=virtualbox

# Check system resources
free -h  # Linux
vm_stat  # macOS

# Enable virtualization in BIOS (if needed)
```

#### 2. Pods Stuck in Pending

**Symptom:** Pods remain in Pending state

**Possible Causes:**
- Insufficient cluster resources
- PVC not bound
- Node not ready

**Solution:**
```bash
# Check pod events
kubectl describe pod <pod-name> -n <namespace>

# Check node resources
kubectl top nodes
kubectl describe node minikube

# Increase cluster resources
minikube stop
minikube start --cpus=4 --memory=8192

# Check PVC status
kubectl get pvc -A
```

#### 3. PVC Not Binding

**Symptom:** PVC stuck in Pending

**Possible Causes:**
- Storage provisioner not running
- Insufficient disk space
- Storage class issues

**Solution:**
```bash
# Check storage provisioner
kubectl get pods -n kube-system -l app=storage-provisioner

# Check storage class
kubectl get storageclass

# Check disk space in minikube
minikube ssh "df -h"

# Manually provision volume
kubectl get pvc <pvc-name> -n <namespace> -o yaml
```

#### 4. Service Not Accessible

**Symptom:** Cannot access service via minikube service or tunnel

**Possible Causes:**
- Service not created
- Minikube tunnel not running
- Firewall blocking access

**Solution:**
```bash
# Check service
kubectl get svc -n vault vault

# Use minikube service
minikube service vault -n vault

# Start minikube tunnel
sudo minikube tunnel

# Use port-forward as alternative
kubectl port-forward -n vault svc/vault 8200:8200
```

#### 5. Vault Pods Crashing

**Symptom:** Vault pods in CrashLoopBackOff

**Possible Causes:**
- License file missing
- Configuration errors
- Resource constraints

**Solution:**
```bash
# Check pod logs
kubectl logs vault-0 -n vault

# Verify license file
ls -la vault-ent/vault-license.lic

# Check pod resources
kubectl describe pod vault-0 -n vault

# Increase pod resources
helm upgrade vault hashicorp/vault \
  --namespace vault \
  --set server.resources.requests.memory=512Mi \
  --set server.resources.requests.cpu=500m
```

#### 6. Minikube Tunnel Issues

**Symptom:** Tunnel fails or requires frequent password entry

**Possible Causes:**
- Insufficient permissions
- Network conflicts
- Multiple tunnels running

**Solution:**
```bash
# Run tunnel with sudo
sudo minikube tunnel

# Check for existing tunnels
ps aux | grep "minikube tunnel"

# Kill existing tunnels
pkill -f "minikube tunnel"

# Use alternative access method
kubectl port-forward -n vault svc/vault 8200:8200
```

### Performance Optimization

```bash
# Increase cluster resources
minikube stop
minikube start --cpus=6 --memory=12288 --disk-size=50g

# Use faster driver
minikube start --driver=hyperkit  # macOS
minikube start --driver=kvm2      # Linux

# Enable caching
minikube start --cache-images=true

# Use SSD for better I/O
# Ensure minikube is on SSD partition
```

## Cleanup

### Uninstall Applications

```bash
# Uninstall VSO and Vault
task uninstall

# Delete application namespaces only
task clean:namespaces

# Verify cleanup
kubectl get pods -A
kubectl get pvc -A
```

### Stop Cluster

```bash
# Stop cluster (preserves state)
minikube stop

# Verify cluster is stopped
minikube status
```

### Delete Cluster

```bash
# Delete cluster completely
task clean

# Or manually
minikube delete

# Verify deletion
minikube status
# Expected: "minikube" does not exist
```

### Clean Docker Resources (if using Docker driver)

```bash
# Remove unused Docker resources
docker system prune -a

# Remove minikube Docker volumes
docker volume ls | grep minikube
docker volume rm $(docker volume ls -q | grep minikube)
```

## Best Practices for Local Development

### Resource Management

1. **Right-size your cluster:**
   - Start small (2 CPU, 4 GB RAM)
   - Increase only when needed
   - Monitor resource usage

2. **Clean up regularly:**
   - Delete unused namespaces
   - Remove old PVCs
   - Prune Docker images

3. **Use pause instead of stop:**
   - Faster resume time
   - Preserves cluster state
   - Saves system resources

### Development Workflow

1. **Use task automation:**
   - Leverage Taskfile for common operations
   - Create custom tasks for your workflow
   - Document task dependencies

2. **Version control:**
   - Commit Kubernetes manifests
   - Track configuration changes
   - Use branches for experiments

3. **Test incrementally:**
   - Test one component at a time
   - Verify each step before proceeding
   - Use descriptive commit messages

### Debugging

1. **Enable verbose logging:**
   - Use `-v=8` for kubectl debugging
   - Enable debug logs in applications
   - Monitor events continuously

2. **Use port-forward liberally:**
   - Direct access to services
   - No need for LoadBalancer
   - Easier debugging

3. **Keep logs accessible:**
   - Save logs before cleanup
   - Use log aggregation tools
   - Archive important debugging sessions

## Comparison: Minikube vs Cloud Platforms

| Feature | Minikube | EKS | GKE |
|---------|----------|-----|-----|
| **Setup Time** | < 5 minutes | 15-20 minutes | 10-15 minutes |
| **Cost** | Free | ~$300/month | ~$160/month |
| **High Availability** | No | Yes | Yes |
| **Scalability** | Limited | High | High |
| **Storage** | Local disk | EBS | Persistent Disk |
| **Load Balancer** | Tunnel/NodePort | AWS NLB/ALB | GCP LB |
| **Best For** | Development, Learning | Production, AWS ecosystem | Production, GCP ecosystem |
| **Persistence** | Until cluster deletion | Independent | Independent |
| **Networking** | Simple | Complex (VPC) | Complex (VPC) |
| **Monitoring** | Basic | CloudWatch | Cloud Monitoring |

## Additional Resources

- [Minikube Documentation](https://minikube.sigs.k8s.io/docs/)
- [Minikube Handbook](https://minikube.sigs.k8s.io/docs/handbook/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Vault on Kubernetes](https://developer.hashicorp.com/vault/tutorials/kubernetes)
- [VSO Documentation](https://developer.hashicorp.com/vault/docs/platform/k8s/vso)
