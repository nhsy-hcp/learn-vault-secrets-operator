# Cloud Deployment (EKS and GKE)

Provision a managed Kubernetes cluster with Terraform, then install Vault, VSO and the examples with the
same tasks used on Minikube. Infrastructure inputs, defaults and outputs are documented in
[`eks/README.md`](../eks/README.md) and [`gke/README.md`](../gke/README.md).

| | EKS | GKE |
|---|---|---|
| Terraform directory | `eks/` | `gke/` |
| Default region | `eu-west-1` | `europe-west1` |
| Cluster name | `eks-hcp` | `vault-<random suffix>` (`terraform -chdir=gke output -raw gke_cluster_name`) |
| Required `terraform.tfvars` | `aws_account_id`, `owner`, `domain` | `project` |
| Vault storage class | `gp2` | cluster default (`standard-rwo`) |

## Prerequisites

- Terraform CLI, kubectl, helm, jq, task
- **EKS**: AWS CLI, authenticated against the target account (`aws sts get-caller-identity`)
- **GKE**: Google Cloud CLI, authenticated (`gcloud auth login` and
  `gcloud auth application-default login`), with the required APIs enabled:

  ```bash
  gcloud services enable container.googleapis.com compute.googleapis.com \
    cloudresourcemanager.googleapis.com iamcredentials.googleapis.com
  ```

- Vault Enterprise license at `vault-ent/vault-license.lic` (see the [README](../README.md#prerequisites))

## Deploy

```bash
task eks:all    # or: task gke:all
task install
task secrets
```

`eks:all` / `gke:all` formats, initialises, validates and applies the Terraform without prompting, then
updates your kubeconfig. To refresh kubeconfig later, run `task eks:eks-credentials` or
`task gke:credentials`. EKS takes 25+ minutes and GKE 20+ minutes.

`task install` detects the platform from the kubectl context and picks the storage class accordingly
(see [Architecture](architecture.md)).

## Verify

```bash
# EKS - expect "ACTIVE"
aws eks describe-cluster --name eks-hcp --region eu-west-1 --query cluster.status

# GKE - expect "RUNNING"
gcloud container clusters describe "$(terraform -chdir=gke output -raw gke_cluster_name)" \
  --region europe-west1 --format='value(status)'

kubectl get pods -A
task verify
```

## Destroy

```bash
task uninstall             # optional: remove Vault, VSO and apps first
task eks:destroy:auto      # or: task gke:destroy:auto
```

Destroy takes 15-20+ minutes. Wait a few minutes for asynchronous deletions (load balancers, disks)
before confirming with the verify command above, which should then return a not-found error.
