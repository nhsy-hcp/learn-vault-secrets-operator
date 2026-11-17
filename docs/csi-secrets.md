# CSI Secrets Example

Mounts secrets straight into the pod filesystem through the **VSO CSI driver**
(`csi.vso.hashicorp.com`), configured by a `CSISecrets` resource. No Kubernetes `Secret` object is
ever created: the data exists only in the pod's tmpfs volume.

- Manifests: [`vault-ent/csi-secrets/`](../vault-ent/csi-secrets/)
- Tasks: `task config:csi-secret`, `task deploy:csi-secret`, `task verify:csi-secret`, `task rotate:csi:secret`, `task restart:csi-secret`
- Requires VSO installed with `csi.enabled: true` (set in `vault-ent/vault-operator-values.yaml`)

## Architecture

```mermaid
flowchart TB
  classDef app fill:#ffffff,stroke:#4b5563,stroke-width:2px,color:#111827
  classDef vso fill:#dbeafe,stroke:#2563eb,stroke-width:2px,color:#1e3a8a
  classDef vault fill:#f3f4f6,stroke:#374151,stroke-width:2px,color:#111827
  classDef out fill:#ecfdf5,stroke:#15803d,stroke-width:2px,color:#14532d
  classDef k8s fill:#e5e7eb,stroke:#6b7280,stroke-width:2px,color:#111827
  subgraph app["csi-app"]
    POD("<b>Pod</b><br/>csi-app")
    CS("<b>CSISecrets</b><br/>csi-demo")
    VA("<b>VaultAuth</b><br/>csi-auth")
    SA("<b>ServiceAccount</b><br/>csi-app-sa")
    TMPFS("<b>tmpfs volume</b><br/>/secrets/static")
  end

  subgraph vso["vault-secrets-operator"]
    DRV("<b>VSO CSI driver</b><br/>csi.vso.hashicorp.com")
  end

  subgraph vault["Vault Enterprise · namespace tn001"]
    ROLE("<b>auth/k8s-auth-mount</b><br/>role: csi-secret")
    KV[("<b>kvv2/db-creds</b>")]
  end

  POD -->|① CSI volume| DRV
  DRV -->|② reads| CS
  CS --> VA
  VA -.->|uses| SA
  DRV -->|③ JWT login| ROLE
  ROLE -->|④| KV
  DRV -->|⑤| TMPFS
  TMPFS -.->|mounted into| POD

  class POD,CS,VA app
  class SA k8s
  class DRV vso
  class ROLE,KV vault
  class TMPFS out
  style app fill:#fff7ed,stroke:#ea580c,stroke-width:2px,color:#9a3412
  style vso fill:#eff6ff,stroke:#2563eb,stroke-width:2px,color:#1e3a8a
  style vault fill:#f9fafb,stroke:#374151,stroke-width:2px,color:#111827
  linkStyle 3 stroke:#9ca3af,stroke-dasharray:4
  linkStyle 6,7 stroke:#15803d,stroke-width:2px
```

Nothing is persisted as a `Secret`, so the data disappears with the pod. The trade-off is that
anything that can't mount the volume can't read the data.

## CSISecrets resource

`csi-demo` does three jobs:
- **Declares the secret:** `kvv2/db-creds`, authenticated through `VaultAuth/csi-auth`.
- **Restricts which pods may mount it:** `accessControl` checks the service account (`csi-app-sa`),
  the namespace (`csi-app`) and the pod name (`^csi-app-*`).
- **Renders the files:** every raw key is excluded, and templates produce `dbUsername` and
  `dbPassword`.

## Vault configuration

**CSI Secrets Role**
- Role name: `csi-secret` (JWT, `user_claim` = service account name)
- Policy: `csi-secret`
- Bound service account / namespace: `csi-app-sa` / `csi-app`
- Audience: `vault`; token period: 1 hour
- Permissions: read `kvv2/data/db-creds`

## Synchronisation flow

1. `task deploy:csi-secret` applies the `ServiceAccount`, `VaultAuth`, `CSISecrets` and the
   deployment.
2. The kubelet mounts the pod's CSI volume. Its `volumeAttributes` name `csi-demo` in `csi-app`.
3. The VSO CSI driver checks the pod against `accessControl`, then logs in to Vault as
   `csi-app-sa` via `k8s-auth-mount`.
4. The driver reads `kvv2/db-creds`, renders the templates and writes `dbUsername` and
   `dbPassword` to a tmpfs volume mounted at `/secrets/static`.
5. After `task rotate:csi:secret`, run `task restart:csi-secret` so new pods mount the new values.

## Related

- [Architecture overview](architecture.md)
- [Static secrets example](static-secrets.md): the same KV mount, delivered as a `Secret`
