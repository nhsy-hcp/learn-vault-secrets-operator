# Vault Agent Sidecar Example (Optional)

Delivers a secret as a **rendered file** rather than a Kubernetes `Secret`, using a Vault Agent init
container. No VSO custom resources are involved at all - this is the pattern to reach for when a
workload wants a config file in its own format.

- Manifests: [`vault-ent/vault-agent-secrets/`](../vault-ent/vault-agent-secrets/)
- Tasks: `task config:vault-agent-secret`, `task deploy:vault-agent-secret`, `task verify:vault-agent-secret`, `task restart:vault-agent-secret`
- **Optional**: not part of `task secrets` or `task all` - run the tasks explicitly
- Requires `task config:static-secret` first, which creates `k8s-auth-mount` and `kvv2/webapp/config`

## Architecture

```mermaid
flowchart LR
  classDef app fill:#ffffff,stroke:#4b5563,stroke-width:2px,color:#111827
  classDef vso fill:#dbeafe,stroke:#2563eb,stroke-width:2px,color:#1e3a8a
  classDef vault fill:#f3f4f6,stroke:#374151,stroke-width:2px,color:#111827
  classDef out fill:#ecfdf5,stroke:#15803d,stroke-width:2px,color:#14532d
  classDef k8s fill:#e5e7eb,stroke:#6b7280,stroke-width:2px,color:#111827
  subgraph app["vault-agent-app"]
    CM("<b>ConfigMap</b><br/>vault-agent-config")
    SA("<b>ServiceAccount</b><br/>vault-agent-sa")

    subgraph pod["Pod vault-agent-app"]
      INIT("<b>initContainer</b><br/>vault-agent-init")
      VOL("<b>emptyDir</b><br/>/vault/secrets")
      APP("<b>container: app</b><br/>reads config.txt")
    end
  end

  subgraph vault["Vault Enterprise · namespace tn001"]
    ROLE("<b>auth/k8s-auth-mount</b><br/>role: vault-agent-secret")
    KV[("<b>kvv2/webapp/config</b>")]
  end

  CM -.->|agent config| INIT
  SA -.->|projected JWT| INIT
  INIT -->|① JWT login| ROLE
  ROLE -->|②| KV
  KV -->|③ template render| VOL
  VOL -->|④| APP

  class CM,SA k8s
  class INIT vso
  class APP app
  class ROLE,KV vault
  class VOL out
  style app fill:#fff7ed,stroke:#ea580c,stroke-width:2px,color:#9a3412
  style pod fill:#ffffff,stroke:#ea580c,stroke-width:1px,stroke-dasharray:4,color:#9a3412
  style vault fill:#f9fafb,stroke:#374151,stroke-width:2px,color:#111827
  linkStyle 0,1 stroke:#9ca3af,stroke-dasharray:4
  linkStyle 4,5 stroke:#15803d,stroke-width:2px
```

The init container exits once the template is rendered; the app container then starts and reads the
file. Nothing is written to the Kubernetes API, so no `Secret` object exists to leak or RBAC.

## Vault configuration

**Vault Agent Role** (optional demo)
- Role name: `vault-agent-secret`
- Policy: `vault-agent-secret`
- Bound service accounts: `vault-agent-sa`
- Bound namespaces: `vault-agent-app`
- Permissions:
  - Read: `kvv2/data/webapp/config`

The policy is read-only on `kvv2/data/webapp/config` - the same secret the
[static secrets example](static-secrets.md) syncs, which makes the two delivery mechanisms easy to
compare side by side.

## Synchronisation flow

The other demos deliver secrets through VSO custom resources. This one uses **no VSO CRs at all** -
a Vault Agent init container authenticates and renders the secret to a shared volume, which is the
pattern to reach for when a workload wants a rendered file rather than a Kubernetes Secret.

```
┌─────────────────────────────────────────────────────────────┐
│  1. Pod starts with a vault-agent-init container            │
│     - config from the vault-agent-config ConfigMap          │
│     - projected JWT at /var/run/secrets                     │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Agent authenticates to Vault                            │
│     - auth/k8s-auth-mount/role/vault-agent-secret in tn001  │
│     - service account vault-agent-sa                        │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  3. Agent renders the template                              │
│     - reads kvv2/data/webapp/config                         │
│     - writes /vault/secrets/config.txt to a shared emptyDir │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  4. Init container exits; app container starts              │
│     - reads the rendered file from the shared volume        │
│     - no Kubernetes Secret is created                       │
└─────────────────────────────────────────────────────────────┘
```

This demo is **optional** and is not part of `task secrets` or `task all`. It reads the same
`kvv2/webapp/config` secret as the Static Secrets demo, so `task config:static-secret` must have run
first to create both `k8s-auth-mount` and the KV data.

## Verifying

```bash
task verify:vault-agent-secret
```

Expect the app container to print the rendered file:

```
Contents of /vault/secrets/config.txt:

USERNAME=static-user
PASSWORD=static-password
```

and the init container logs to show `authentication successful` followed by
`rendered "(dynamic)" => "/vault/secrets/config.txt"`.

## Related

- [Architecture overview](architecture.md)
- [Static secrets example](static-secrets.md) - the same KV secret delivered as a `Secret`
- [CSI secrets example](csi-secrets.md) - another no-`Secret` delivery mechanism
