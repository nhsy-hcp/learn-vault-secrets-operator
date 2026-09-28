# Troubleshooting

Repo-specific symptoms for each example. Start with the automated checks: `task verify` (or
`task verify:<example>`) and `task verify:pods`.

## First response

| Check | Command |
|---|---|
| Pod status | `kubectl get pods -A` |
| Events | `task events` |
| Vault seal status | `task status` |
| Vault logs | `task logs` |
| VSO logs | `task logs:vso` |
| Auth roles | `task list:k8s-auth` |
| Identity entities | `task list:identity-entities` |
| VSO resources | `kubectl get vaultconnection,vaultauth,vaultstaticsecret,vaultdynamicsecret,vaultpkisecret -A` |

## Vault

- **Sealed after a pod restart:** run `task unseal:vault`.
- **`vault-0` stuck `Pending`:** check the PVC and storage class. See
  [storage classes](architecture.md#storage-classes).
- **License errors:** `vault-ent/vault-license.lic` must exist before `task install:vault` creates the
  `vault-license` secret.
- **k3d cluster creation fails with log-read errors (podman):** restart the podman machine with
  `podman machine stop && podman machine start`.

## Static secrets

- The `static-secret` role binds the glob `static-app-*`. Check it with `task list:k8s-auth`.
- Check each instance: `kubectl describe vaultstaticsecret vault-kv-app -n static-app-1` and
  `kubectl get secret secretkv -n static-app-1`.

## Dynamic secrets

- Check the database and PKI syncs:
  `kubectl describe vaultdynamicsecret vso-db-demo -n dynamic-app` and
  `kubectl describe vaultpkisecret vso-pki-demo -n dynamic-app`.
- `task deploy:dynamic-secret` starts PostgreSQL in `dynamic-app` and waits for it before writing
  `db/config/dev-postgres`. A `Pending` PostgreSQL pod usually means a storage-class problem.
- To rotate the credentials, run `task rotate:dynamic-secret`.

## CSI

- VSO must be installed with `csi.enabled=true` (`task install:vso` does this).
- Check the `CSISecrets` resource: `kubectl describe csisecrets csi-demo -n csi-app`.
- After rotating with `task rotate:csi:secret`, remount with `task restart:csi-secret`.

## PKI

- **`403 permission denied` on issue:** the SA's `vault.hashicorp.com/alias-metadata-pki_role`
  annotation is missing or doesn't match the `VaultPKISecret` `role`. After fixing it, re-create
  `VaultAuth/pki-auth` to force a fresh login.
- **Login fails with a service account read error:** Vault can't read the SA's annotations. Check
  that `vault-ent/vault-sa-reader-rbac.yaml` has been applied.
- **`service account name not authorized` / `namespace not authorized`:** the SA must be named
  `pki-app-*-sa` and live in a `pki-app-*` namespace (auth role `pki-secret` on `kubernetes-auth-mount`).
- **`common name ... not allowed by this role`:** the name is outside `allowed_domains` on
  `pki/roles/pki-app-N`. Note that `<name>.<ns>.svc` is a subdomain of `svc`, not of
  `svc.cluster.local`.
- **Pod stuck in `ContainerCreating`:** it mounts `pki-app-tls`, which doesn't exist until the
  certificate is issued. Fix the sync error and the pod recovers.
- **Certificates no longer chain to the CA:** the `pki` mount was re-created with a new root CA. Run
  `task rotate:pki-secret` to re-issue them.

## Entity metadata

- **`403 permission denied`:** either the entity's `team` metadata doesn't match the
  `VaultStaticSecret` path, or the app logged in before onboarding and got an auto-created entity.
  Re-run `task config:entity-secret` to re-point the alias. VSO's existing token may still carry the
  old entity until it logs in again. Restarting the pod or re-applying `VaultAuth/entity-auth` should
  force a fresh login.
- **Service account labels don't show up via `claim_mappings`:** Kubernetes tokens don't carry them.
  See [entity secrets](entity-secrets.md).

## Vault Agent

- Check both containers: `kubectl logs -n vault-agent-app -l app=vault-agent-app -c vault-agent-init`
  should show `authentication successful`, then `rendered "(dynamic)"`.
- The demo requires `task config:static-secret` to have run first.
