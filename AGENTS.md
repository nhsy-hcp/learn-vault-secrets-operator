# Vault Secrets Operator Automation Guide

This project demonstrates the HashiCorp Vault Secrets Operator (VSO) for Kubernetes with automated workflows.

## Prerequisites

### Vault Enterprise License
A Vault Enterprise license is required for this lab. You must place a valid `vault-license.lic` file in the `vault-ent/` directory before running the installation tasks.

```bash
vault-ent/
└── vault-license.lic  # Required: Vault Enterprise license file
```

### Required Tools
- kubectl
- helm
- k3d plus docker or podman (for local development)
- jq
- task (taskfile.dev)
- AWS CLI (for EKS deployments)
- Google Cloud CLI (for GKE deployments)
- Terraform CLI

## Project Structure

- `vault-ent/` - Vault Enterprise configuration files
- `vault-ent/static-secrets/` - Static secret manifests and templates
- `vault-ent/dynamic-secrets/` - Dynamic secret manifests
- `vault-ent/csi-secrets/` - CSI driver configuration and policies
- `vault-ent/pki-secrets/` - PKI certificate manifests and templates (per-app annotated service accounts)
- `vault-ent/entity-secrets/` - Entity metadata manifests, templates and `apps.json` catalogue
- `scripts/` - Helper scripts invoked from the Taskfile
- `vault-ent/vault-agent-secrets/` - Vault Agent sidecar demo (optional)
- `eks/` - EKS infrastructure provisioning
- `gke/` - GKE infrastructure provisioning
- `Taskfile.yml` - Task automation definitions
- `docs/` - Documentation, including one walkthrough per example:
  `static-secrets.md`, `dynamic-secrets.md`, `csi-secrets.md`, `pki-secrets.md`,
  `entity-secrets.md`, `vault-agent-secrets.md`, plus system-level `architecture.md` and
  `cloud-deployment.md` (EKS/GKE) and `troubleshooting.md` (public copy of the Troubleshooting section below)

## Workflows

### Instructions
- Execute the steps sequentially
- If you encounter issues stop for further instructions
- Do not make any changes
- Use AWS region eu-west-1 for AWS CLI
- Use GCP region europe-west1 for Google Cloud CLI

### EKS Deployment workflow
1. Switch to project root directory
2. Run `task eks:all` and wait 3 minutes (25mins+ to complete)
3. Verify eks-hcp eks cluster is in *ACTIVE* state with AWS CLI
4. Wait for pods to stabilize and in *Running* status
5. Inspect pods logs for any errors

### EKS Destroy workflow
1. Switch to project root directory
2. Run `task eks:destroy:auto` (20mins+ to complete)
3. Wait 3 minutes for asynchronous deletions to complete
4. Verify eks-hcp eks cluster has been destroyed with AWS CLI
5. Continue with install deployment workflow

### GKE Deployment workflow
1. Switch to project root directory
2. Run `task gke:all` and wait 3 minutes (20mins+ to complete)
3. Verify the GKE cluster (`vault-<suffix>`, see `terraform -chdir=gke output -raw gke_cluster_name`) is in *RUNNING* state with Google Cloud CLI
4. Wait for pods to stabilize and in *Running* status
5. Inspect pods logs for any errors

### GKE Destroy workflow
1. Switch to project root directory
2. Run `task gke:destroy:auto` (15mins+ to complete)
3. Wait 3 minutes for asynchronous deletions to complete
4. Verify the `vault-<suffix>` GKE cluster has been destroyed with Google Cloud CLI (`gcloud container clusters list --region europe-west1`)

### k3d Deployment workflow
1. Switch to project root directory
2. Run `task cluster:up`
3. Continue with install deployment workflow

### k3d Destroy workflow
1. Switch to project root directory
2. Run `task clean`

### Install workflow
1. Run `task install` (Vault and VSO only), then `task secrets` (deploys and verifies the example apps)
2. Wait for pods to stabilize and in *Running* status
3. Inspect pods logs for any errors
4. Verify secrets are mounted successfully in pod logs (static: /secrets/static, dynamic: /secrets/dynamic/db and /secrets/dynamic/tls, csi: /secrets/static, pki: /etc/tls, entity: /secrets/entity)
5. Verify VaultStaticSecret/vault-kv-app has been deployed successfully across all static-app-* and entity-app-* namespaces
6. Verify Secrets/secretkv has been created successfully in all static-app-* and entity-app-* namespaces

### Uninstall workflow
1. Switch to project root directory
2. Run `task uninstall`
3. Verify pods & namespaces have been deleted:
   - vault
   - vault-secrets-operator
   - csi-app
   - static-app-1, static-app-2, static-app-3
   - dynamic-app
   - pki-app-1, pki-app-2, pki-app-3
   - entity-app-1, entity-app-2, entity-app-3
   - vault-agent-app (if deployed)

## Automation Commands

### Complete Setup
```bash
task all
```
Runs the complete tutorial: prerequisites, k3d cluster (`task cluster:up`), `task install` and `task secrets`.

### Cluster Tasks (k3d)
- `task cluster:up` (aliases `start`, `k3d`) - Create or start the k3d cluster `vso-lab` (context `k3d-vso-lab`); idempotent
- `task cluster:stop` (alias `stop`) - Stop the k3d cluster
- `task cluster:down` - Delete the k3d cluster

### Core Setup Tasks
- `task install` - Install and configure Vault and VSO on existing cluster
- `task install:vault` - Install Vault using Helm
- `task init:vault` - Initialize Vault and save keys to vault-init.json
- `task unseal:vault` - Unseal Vault using saved keys
- `task config:vault` - Configure Vault with namespaces and JWT token reviewer service account
- `task config:vso:encrypted-cache` - Configure Vault transit engine for VSO encrypted client cache
- `task install:vso` - Install Vault Secrets Operator with CSI enabled

### Deployment Tasks
- `task secrets` - Configure and deploy all secret types (static, dynamic, CSI, PKI, and entity metadata) with verification
- `task config:static-secret` - Configure Vault for static KV secrets in tn001 namespace (creates 3 static app namespaces)
- `task deploy:static-secret` - Deploy static secret resources for all app instances using templates
- `task config:dynamic-secret` - Configure Vault for dynamic database secrets and PKI in tn001 namespace
- `task deploy:dynamic-secret` - Deploy dynamic secret resources with PostgreSQL database and PKI certificates
- `task deploy:csi-secret` - Deploy CSI demo application with CSI driver integration
- `task config:pki-secret` - Create the `pki-app-*` namespaces, the `kubernetes-auth-mount` kubernetes auth mount, templated policy/role and per-app PKI roles (via `scripts/config-pki-secret.sh`)
- `task deploy:pki-secret` - Deploy PKI certificate resources for all app instances using templates
- `task config:entity-secret` - Create the `entity-app-*` namespaces, seed per-team KV secrets, write the templated policy and role, and pre-create identity entities from `apps.json` (via `scripts/config-entity-secret.sh`)
- `task deploy:entity-secret` - Deploy entity metadata resources for every app in `apps.json`

### Verification Tasks
- `task verify` - Run all verification tasks
- `task verify:static-secret` - Verify static secret synchronization across all app instances
- `task verify:dynamic-secret` - Verify dynamic database and PKI certificate synchronization
- `task verify:csi-secret` - Verify CSI secrets and display application logs
- `task verify:pki-secret` - Verify PKI certificates were issued for all app instances
- `task verify:entity-secret` - Verify entity metadata/aliases and per-team secret sync
- `task verify:pods` - Check all pod status across namespaces

### CSI Integration Tasks
- `task config:csi-secret` - Configure Vault for CSI integration in tn001 namespace
- `task restart:csi-secret` - Rollout restart CSI application

### Vault Agent Tasks (Optional)
Not chained into `task secrets` or `task all` - run these explicitly. Requires
`task config:static-secret` to have created `k8s-auth-mount` and `kvv2/webapp/config`.

- `task config:vault-agent-secret` - Configure Vault policy and auth role for the Vault Agent demo
- `task deploy:vault-agent-secret` - Deploy the Vault Agent sidecar demo application
- `task verify:vault-agent-secret` - Verify Vault Agent rendered the secret into the pod
- `task restart:vault-agent-secret` - Rollout restart the Vault Agent demo application

### Secret Management Tasks
- `task rotate:static-secret` - Rotate static secret values in Vault and verify synchronization
- `task rotate:dynamic-secret` - Rotate dynamic database secret by revoking leases and restarting deployment
- `task rotate:csi:secret` - Rotate CSI secret values in Vault
- `task rotate:pki-secret` - Rotate PKI certificates by deleting the synced TLS secrets (reuses VSO's cached
  Vault token, so it does not pick up changed SA annotations)

### Cleanup Tasks
- `task clean` - Delete the k3d cluster (`task cluster:down`) and vault-init.json
- `task uninstall` - Complete uninstall of VSO and Vault
- `task uninstall:vault` - Remove Vault installation
- `task uninstall:vso` - Remove VSO installation
- `task uninstall:apps` - Remove all application deployments and resources
- `task clean:namespaces` - Delete the `vault` and `vault-secrets-operator` namespaces
- `task eks:destroy:auto` - Destroy EKS cluster (automated)
- `task gke:destroy:auto` - Destroy GKE cluster (automated)

### Code Quality Tasks
- `task lint` - Run pre-commit hooks on all files
- `task lint:eks` - Run tflint on EKS Terraform configuration
- `task lint:gke` - Run tflint on GKE Terraform configuration

### Debugging Tasks
- `task status` - Check Vault status
- `task logs` - Follow Vault logs
- `task logs:vso` - Follow VSO logs
- `task port-forward` - Port forward Vault to localhost:8200 (EKS/GKE; on k3d Vault is already on localhost:8200 via NodePort 30820)
- `task list:k8s-auth` - Display the tn001 `k8s-auth-mount` (JWT) roles and config; for PKI use
  `vault read auth/kubernetes-auth-mount/role/pki-secret` or `task verify:pki-secret`
- `task list:identity-entities` - Display identity entities with detailed information
- `task events` - Display Kubernetes events
- `task token` - Copy root token to clipboard
- `task ui` - Copy root token and open Vault UI

### Verification Commands
```bash
# Check EKS cluster status
aws eks describe-cluster --name eks-hcp --region eu-west-1

# Check GKE cluster status
gcloud container clusters describe "$(terraform -chdir=gke output -raw gke_cluster_name)" --region europe-west1

# Check all pods
kubectl get pods -A

# Check specific namespace pods
kubectl get pods -n vault
kubectl get pods -n vault-secrets-operator
kubectl get pods -n static-app-1
kubectl get pods -n static-app-2
kubectl get pods -n static-app-3
kubectl get pods -n dynamic-app
kubectl get pods -n csi-app
kubectl get pods -n pki-app-1
kubectl get pods -n pki-app-2
kubectl get pods -n pki-app-3
kubectl get pods -n entity-app-1
kubectl get pods -n entity-app-2
kubectl get pods -n entity-app-3
kubectl get pods -n vault-agent-app   # only if the optional demo is deployed

# Check VSO custom resources
kubectl get vaultauth -A
kubectl get vaultstaticsecret -A
kubectl get vaultpkisecret -A

# Inspect an issued PKI certificate
kubectl get secret pki-app-tls -n pki-app-1 -o jsonpath='{.data.tls\.crt}' \
  | base64 -d | openssl x509 -noout -subject -issuer -enddate -ext subjectAltName

# Get pod logs
kubectl logs -n csi-app -l app=csi-app --tail=50
kubectl logs -n static-app-1 -l app=static-app --tail=50
kubectl logs -n pki-app-1 -l app=pki-app --tail=50
kubectl logs -n entity-app-1 -l app=entity-app --tail=50

# Check events
kubectl get events -A --sort-by='.lastTimestamp'
```

## Environment Configuration

The project uses a `.env` file for sensitive configuration:
- `VAULT_TOKEN` - Root token (automatically set by task init:vault)

## Vault Configuration Details

### Auth Mounts
- `vso` namespace: `k8s-auth-mount` is a `kubernetes` auth mount using the token reviewer JWT from
  service account `vault-token-reviewer` in `vault` (secret `vault-token-secret`, ClusterRoleBinding `vault-reviewer-binding`)
- `tn001` namespace: `k8s-auth-mount` is a `jwt` auth mount validating service account tokens via the
  cluster's OIDC discovery endpoint (ClusterRoleBinding `oidc-discovery-public`); created by
  `task config:static-secret` and used by every example app except PKI
- `tn001` namespace: `kubernetes-auth-mount` is a `kubernetes` auth mount (token reviewer `vault-token-reviewer`,
  `use_annotations_as_alias_metadata=true`, ClusterRole `vault-sa-reader` from `vault-ent/vault-sa-reader-rbac.yaml`);
  created by `task config:pki-secret` and used by the PKI example

### Static Secrets (Multiple Instances)
- Namespace: `tn001`
- Mount: `kvv2`
- Path: `kvv2/webapp/config`
- Auth role: `static-secret` (uses glob pattern `static-app-*` for multiple instances)
- Service account: `static-app-sa` (in namespaces `static-app-1`, `static-app-2`, `static-app-3`)
- Auth mount: `k8s-auth-mount`
- Deployment: Template-based deployment from `vault-ent/static-secrets/templates/`
- Instance count: Configurable via `static_app_count` variable (default: 3)

### Dynamic Secrets
- Namespace: `tn001`
- Database mount: `db`
- Database path: `creds/dev-postgres`
- PKI mount: `pki` (shared with the PKI demo, which adds the `pki-app-N` roles)
- PKI role: `example-dot-com`
- Root CA: seeded only when `pki/cert/ca` is absent, so `config:dynamic-secret` and
  `config:pki-secret` converge on the same CA in either order and can be re-run safely
- Auth role: `dynamic-secret`
- Service account: `dynamic-app-sa` in `dynamic-app` namespace
- Auth mount: `k8s-auth-mount`

### PKI Secrets
- Namespace: `tn001`
- PKI mount: `pki` (shared with dynamic secrets, which uses the `example-dot-com` role)
- Issuing roles: `pki-app-N`, one per app, `allowed_domains` limited to that app's names
- Auth role: `pki-secret` (kubernetes role, SA names `pki-app-*-sa`, namespaces `pki-app-*`,
  `alias_name_source=serviceaccount_name`)
- Policy: `pki-secret` - templated `pki/issue/{{identity.entity.aliases.<accessor>.metadata.pki_role}}`
  (accessor substituted at config time; issuance only, no revoke)
- Service account: `<ns>-sa` with `vault.hashicorp.com/alias-metadata-*` annotations `pki_role`, `application_name`,
  `namespace` (= `<ns>`), `team: platform`, `business_unit: shared-services`
- Auth mount: `kubernetes-auth-mount` (kubernetes); no entities are pre-created
- VaultAuth: `pki-auth` per `pki-app-*` namespace (`method: kubernetes`)
- Script: `scripts/config-pki-secret.sh` (auth mount + config, templated policy, role, `pki/roles/pki-app-N`)
- Deployment: Template-based deployment from `vault-ent/pki-secrets/templates/`
- Instance count: Configurable via `pki_app_count` variable (default: 3)

### Entity Metadata Secrets
- Namespace: `tn001`
- KV secrets: `kvv2/teams/<team>/config` (one per distinct team in `apps.json`)
- Auth role: `entity-secret` (`user_claim` SA name, globs `entity-app-*` / `entity-app-*-sa`, `claim_mappings` for namespace and SA name,
  audience `vault`, `token_period` 3600)
- Policy: `entity-secret` - templated on `{{identity.entity.metadata.team}}`, plus `subscribe` / `sys/events/subscribe/kv*`
  for the `VaultStaticSecret`'s `instantUpdates`
- Service account: `<ns>-sa`, unique per namespace (`entity-app-1-sa`, `entity-app-2-sa`, `entity-app-3-sa`)
- Auth mount: `k8s-auth-mount`
- Entities: pre-created by `scripts/config-entity-secret.sh` with `application_name`, `team`, `business_unit`, `namespace`
  metadata; alias `<ns>-sa`
- Catalogue: `vault-ent/entity-secrets/apps.json` (payments-api and payments-portal: payments/retail; risk-engine: risk/corporate),
  set by the `entity_apps_file` variable; one app instance per entry
- Metadata keys use lowercase snake_case, which is safe in policy templates
- Depends on `task config:static-secret` having created `k8s-auth-mount` and `kvv2`

### Vault Agent Sidecar (Optional)
- Namespace: `tn001`
- KV secret: `kvv2/webapp/config` (shared with the static secrets demo)
- Auth role: `vault-agent-secret`
- Policy: `vault-agent-secret` (read only)
- Service account: `vault-agent-sa` in `vault-agent-app` namespace
- Auth mount: `k8s-auth-mount`
- Delivery: Vault Agent init container renders `/vault/secrets/config.txt` - no VSO CRs involved
- **Not** chained into `task secrets` or `task all`; run the three tasks explicitly
- Depends on `task config:static-secret` having created `k8s-auth-mount` and `kvv2/webapp/config`

### CSI Driver Integration
- Namespace: `tn001`
- KV secrets: `kvv2/db-creds`
- Auth role: `csi-secret`
- Service account: `csi-app-sa` in `csi-app` namespace
- Auth mount: `k8s-auth-mount` (same JWT mount as static/dynamic)

### Encrypted Client Cache
- Namespace: `vso`
- Transit engine: `vso-transit`
- Key: `vso-client-cache`
- Auth role: `auth-role-operator`
- Service account: `vault-secrets-operator-controller-manager` in `vault-secrets-operator` namespace
- Auth mount: `k8s-auth-mount`

## Troubleshooting

### Pod Issues
1. Check pod status: `kubectl get pods -A`
2. Describe problematic pod: `kubectl describe pod <pod-name> -n <namespace>`
3. Check logs: `kubectl logs <pod-name> -n <namespace>`
4. Check events: `kubectl get events -n <namespace> --sort-by='.lastTimestamp'`

### Vault Issues
1. Check seal status: `task status`; Vault is sealed after a pod restart - run `task unseal:vault`
2. View logs: `task logs`
3. Verify auth configuration: `task list:k8s-auth`
4. Check identity entities: `task list:identity-entities`
5. `vault-0` stuck `Pending` - check the PVC and storage class (see `docs/architecture.md#storage-classes`)
6. License errors - `vault-ent/vault-license.lic` must exist before `task install:vault` creates the
   `vault-license` secret
7. k3d cluster creation fails with log-read errors on podman - restart the podman machine
   (`podman machine stop && podman machine start`)

### VSO Issues
1. Check operator logs: `task logs:vso`
2. Verify VaultConnection: `kubectl get vaultconnection -A`
3. Verify VaultAuth: `kubectl get vaultauth -A`
4. Verify secret sync: `kubectl describe vaultstaticsecret -n static-app-1`

### Static Secrets Issues
1. Verify all static app instances are running: `kubectl get pods -n static-app-1 -n static-app-2 -n static-app-3`
2. Check VaultStaticSecret resources in each namespace: `kubectl get vaultstaticsecret -A`
3. Verify glob pattern matching in Vault role: `task list:k8s-auth`
4. Check synced secrets in each namespace: `kubectl get secret secretkv -n static-app-1`

### PKI Issues
1. Check certificate sync status: `kubectl get vaultpkisecret -A`
2. `403 permission denied` on issue - the SA's `alias-metadata-pki_role` annotation is missing or does not
   match the `VaultPKISecret` `role`; after fixing, re-create `VaultAuth/pki-auth` to force a fresh login
   (metadata is only refreshed at login)
3. Login fails reading the service account - `vault-ent/vault-sa-reader-rbac.yaml` is not applied
4. `service account name/namespace not authorized` - SA must be `pki-app-*-sa` in a `pki-app-*` namespace
   (`vault read auth/kubernetes-auth-mount/role/pki-secret`)
5. `common name ... not allowed by this role` - name is outside `allowed_domains` on
   `pki/roles/pki-app-N`; note `<name>.<ns>.svc` is a subdomain of `svc`, not `svc.cluster.local`
6. Pod stuck in `ContainerCreating` - it mounts `pki-app-tls`, which does not exist until the
   certificate is issued; fix the sync error and the pod recovers
7. Certificates no longer chain to the CA - the `pki` mount was re-created (e.g. by
   `task uninstall:apps`) with a new root CA; run `task rotate:pki-secret` to re-issue

### Entity Metadata Issues
1. Check entity metadata and aliases: `task verify:entity-secret` or `task list:identity-entities`
2. `403 permission denied` - the entity's `team` metadata does not match the `VaultStaticSecret` path,
   or the app logged in before onboarding and got an auto-created entity; re-run
   `task config:entity-secret` to re-point the alias. VSO's existing token may still carry the old
   entity until it re-authenticates - restarting the pod or re-applying `VaultAuth/entity-auth` should
   force a fresh login
3. Service account labels cannot be mapped with `claim_mappings` - Kubernetes tokens do not carry them

### Vault Agent Issues
1. Check both containers: `kubectl logs -n vault-agent-app -l app=vault-agent-app -c app` and
   `-c vault-agent-init`
2. The init container must log `authentication successful` then `rendered "(dynamic)"`
3. Requires `task config:static-secret` to have run first (creates `k8s-auth-mount` and the KV secret)

## Architecture Notes

### Auth Mount Design
- **`vso` (Kubernetes auth + token reviewer)**: a long-lived token for service account `vault-token-reviewer`
  (`vault-ent/vault-jwt-service-account.yaml`, `vault-jwt-clusterrolebinding.yaml` with
  `system:auth-delegator`, `vault-jwt-secret.yaml`) lets Vault call the TokenReview API for the VSO
  operator's encrypted-cache login.
- **`tn001` (JWT auth + OIDC discovery)**: Vault verifies app service account tokens offline against
  the cluster's OIDC issuer (`vault-ent/oidc-discovery-clusterrolebinding.yaml` makes discovery
  public). On k3d the issuer is in-cluster (`https://kubernetes.default.svc.cluster.local`), so the
  service-account CA is supplied as `oidc_discovery_ca_pem` and
  `task cluster:up` enables apiserver `anonymous-auth` (off by default in k3s); on EKS/GKE the public endpoint uses the system CA
  bundle. All example roles except PKI are JWT roles with `bound_claims` on this mount.
- **`tn001` `kubernetes-auth-mount` (Kubernetes auth + SA annotations)**: reuses the `vault-token-reviewer`
  token for TokenReview; `vault-ent/vault-sa-reader-rbac.yaml` adds `get serviceaccounts` so
  `use_annotations_as_alias_metadata` can copy `vault.hashicorp.com/alias-metadata-*` annotations into alias
  metadata. Mount, templated policy (accessor substituted by `sed`) and roles are written by
  `scripts/config-pki-secret.sh`.

### PKI Architecture
- **Separate kubernetes auth mount**: JWT auth cannot read ServiceAccount annotations, so PKI uses
  `kubernetes-auth-mount` with `use_annotations_as_alias_metadata=true`. Vault reads each SA (hence the
  `vault-sa-reader` ClusterRole) and copies `vault.hashicorp.com/alias-metadata-<key>` annotations into alias metadata.
- **Templated policy**: `pki_role` metadata picks the issuing role, so each app can only use its own
  `pki/roles/pki-app-N`, whose `allowed_domains` cover only that app's names.
- **No pre-created entities**: unlike the entity demo, metadata comes from annotations at login. Anyone
  who can edit SAs in a `pki-app-*` namespace can change it.
- **Issuance only**: the policy omits `pki/revoke`, so `VaultPKISecret` does not set `revoke: true`.

### Static Secrets Architecture
The static secrets implementation supports multiple application instances using:
- **Glob Pattern Matching**: The `static-secret` Vault role uses `bound_service_account_namespaces: "static-app-*"` to authorize all static app instances
- **Template-Based Deployment**: Manifests are generated from templates in `vault-ent/static-secrets/templates/` with `${APP_NAME}` substitution
- **Configurable Instance Count**: The `static_app_count` variable (default: 3) controls how many instances are deployed
- **Dedicated Resources**: Each instance gets its own namespace, service account, VaultAuth, VaultStaticSecret, and deployment

### Platform-Specific Storage Classes
`install:vault` and the PostgreSQL deployment pick a storage class from the kubectl context
(EKS `gp2`, GKE `standard-rwo`/default, k3d `local-path`) - see
[`docs/architecture.md#storage-classes`](docs/architecture.md#storage-classes).

## Notes

- All Vault initialization keys are stored in `vault-init.json` (excluded from git)
- Root token is automatically added to `.env` file
- Platform-specific storage classes are automatically configured during Vault installation (see Architecture Notes)
- CSI driver requires VSO to be installed with `csi.enabled=true`
- Wait times between steps allow for asynchronous Kubernetes operations to complete
- The `deploy:static-secret` task uses templates to deploy multiple static app instances
- Static secrets use glob pattern matching (`static-app-*`) to support multiple instances
- Dynamic secrets include both database credentials (PostgreSQL) and PKI certificates (TLS)
- The `static_app_count` variable controls the number of static app instances (default: 3)
- The `pki_app_count` variable controls the number of PKI app instances (default: 3)
- The PKI demo derives Vault alias metadata from ServiceAccount annotations (kubernetes auth), whereas the
  entity demo pre-creates entities (JWT auth); both use the same metadata keys
- `pki-app-3` requests a wildcard certificate; all instances also carry a `pki-app-N.example.com` SAN so one
  Secret could serve both the pod and a load balancer
- The entity metadata demo pre-creates Vault entities because Kubernetes tokens do not carry
  ServiceAccount labels; each namespace has a unique service account name so it gets its own alias
- Pre-created entities survive `vault auth disable`; `task uninstall:apps` deletes them by name
  (auto-created `entity_*` entities, `kvv2/teams/*` secrets and the `entity-secret` policy remain)
- Vault client counts take at least 10 minutes to generate after startup; an empty or zero count
  before then is expected, not a sign that entity or auth configuration failed
- SA annotation metadata is only read at login; after changing an annotation, re-create `VaultAuth/pki-auth`
  to force VSO to re-authenticate
- `task uninstall:apps` disables `kubernetes-auth-mount` and deletes the `vault-sa-reader` RBAC
- The Vault Agent demo is optional and excluded from `task secrets` / `task all`
