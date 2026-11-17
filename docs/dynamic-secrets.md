# Dynamic Secrets Example

Generates short-lived PostgreSQL credentials and an X.509 certificate on demand, so nothing
long-lived is stored in Kubernetes.

- Manifests: [`vault-ent/dynamic-secrets/`](../vault-ent/dynamic-secrets/)
- Tasks: `task config:dynamic-secret`, `task deploy:dynamic-secret`, `task verify:dynamic-secret`, `task rotate:dynamic-secret`
- Includes a PostgreSQL deployment for the database engine to issue credentials against

## Architecture

```mermaid
%%{init: {"flowchart": {"wrappingWidth": 300}}}%%
flowchart TB
  classDef app fill:#ffffff,stroke:#4b5563,stroke-width:2px,color:#111827
  classDef vso fill:#dbeafe,stroke:#2563eb,stroke-width:2px,color:#1e3a8a
  classDef vault fill:#f3f4f6,stroke:#374151,stroke-width:2px,color:#111827
  classDef out fill:#ecfdf5,stroke:#15803d,stroke-width:2px,color:#14532d
  classDef k8s fill:#e5e7eb,stroke:#6b7280,stroke-width:2px,color:#111827
  subgraph app["dynamic-app"]
    VDS("<b>VaultDynamicSecret</b><br/>vso-db-demo")
    VPS("<b>VaultPKISecret</b><br/>vso-pki-demo")
    VA("<b>VaultAuth</b><br/>dynamic-auth")
    SDB("<b>Secret</b><br/>vso-db-demo")
    STLS("<b>Secret</b><br/>vso-pki-demo<br/>kubernetes.io/tls")
    POD("<b>Pod</b><br/>dynamic-app")
    PG[("<b>PostgreSQL</b>")]
  end

  subgraph vso["vault-secrets-operator"]
    OP("<b>VSO controller</b>")
  end

  subgraph vault["Vault Enterprise · namespace tn001"]
    ROLE("<b>auth/k8s-auth-mount</b><br/>role: dynamic-secret")
    DB[("<b>db/creds/dev-postgres</b>")]
    PKI[("<b>pki/issue/example-dot-com</b>")]
  end

  VDS -.->|vaultAuthRef| VA
  VPS -.->|vaultAuthRef| VA
  OP -->|① watches| VDS
  OP -->|① watches| VPS
  VA -->|② JWT login| ROLE
  ROLE -->|③| DB
  ROLE -->|③| PKI
  OP -->|④| SDB --> POD
  OP -->|④| STLS --> POD
  POD ==>|⑤ connects with issued creds| PG

  class VDS,VPS,VA,POD app
  class OP vso
  class ROLE,DB,PKI vault
  class SDB,STLS,PG out
  style app fill:#fff7ed,stroke:#ea580c,stroke-width:2px,color:#9a3412
  style vso fill:#eff6ff,stroke:#2563eb,stroke-width:2px,color:#1e3a8a
  style vault fill:#f9fafb,stroke:#374151,stroke-width:2px,color:#111827
  linkStyle 0,1 stroke:#9ca3af,stroke-dasharray:4
  linkStyle 7,8,9,10,11 stroke:#15803d,stroke-width:2px
```

Credentials carry a lease and are revoked when it expires; the certificate is renewed by VSO before
it lapses.

## Vault configuration

**Dynamic Secrets Role**
- Role name: `dynamic-secret`
- Policy: `dynamic-secret`
- Bound service accounts: `dynamic-app-sa`
- Bound namespaces: `dynamic-app`
- Token TTL: 1 hour
- Permissions:
  - Read: `db/creds/dev-postgres`
  - Read: `pki/issue/example-dot-com`

## Synchronisation flow

```
┌─────────────────────────────────────────────────────────────┐
│  1. User creates VaultDynamicSecret CRD                     │
│     - Specifies Vault path: db/creds/dev-postgres           │
│     - Defines renewal and rotation settings                 │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  2. VSO Controller watches VaultDynamicSecret               │
│     - Detects new/updated resource                          │
│     - Reads VaultAuth configuration                         │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  3. VSO authenticates to Vault                              │
│     - Uses app service account token                        │
│     - Receives Vault token with dynamic-secret policy       │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  4. VSO requests dynamic credentials                        │
│     - Calls db/creds/dev-postgres                           │
│     - Vault generates new DB credentials                    │
│     - Credentials have TTL (default: 1 hour)                │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  5. VSO creates Kubernetes Secret                           │
│     - Stores username and password                          │
│     - Includes lease information                            │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  6. VSO manages credential lifecycle                        │
│     - Renews lease before expiration                        │
│     - Rotates credentials based on policy                   │
│     - Updates K8s Secret with new credentials               │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  7. Application pod consumes credentials                    │
│     - Mounts as volume at /secrets/dynamic/db               │
│     - Automatically gets updated credentials                │
└─────────────────────────────────────────────────────────────┘
```

## Data flow

```
┌──────────────┐
│   Vault DB   │
│    Engine    │
└──────┬───────┘
       │
       │ 1. VSO requests credentials
       ▼
┌──────────────┐     2. Generates     ┌──────────────┐
│     VSO      │◄────credentials──────│  PostgreSQL  │
│  Controller  │                      │   Database   │
└──────┬───────┘                      └──────────────┘
       │
       │ 3. Creates K8s Secret with credentials
       ▼
┌──────────────┐
│  Kubernetes  │
│    Secret    │
└──────┬───────┘
       │
       │ 4. Mounted to pod
       ▼
┌──────────────┐
│ Application  │
│     Pod      │
└──────────────┘
       │
       │ 5. Uses credentials
       ▼
┌──────────────┐
│  PostgreSQL  │
│   Database   │
└──────────────┘
```

## Related

- [Architecture overview](architecture.md)
- [PKI example](pki-secrets.md) - cert-manager `VaultClusterIssuer` on the same `pki` mount
