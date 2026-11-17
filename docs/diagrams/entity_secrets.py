"""Entity metadata lab: pre-created Vault entities and a templated policy pick each team's KV path."""

from diagrams.k8s.compute import Deployment
from diagrams.k8s.controlplane import ControllerManager
from diagrams.k8s.others import CRD
from diagrams.k8s.podconfig import Secret
from diagrams.k8s.rbac import ServiceAccount
from diagrams.onprem.security import Vault
from diagrams.programming.language import Bash

from common import YELLOW, YELLOW_FILL, app_ns, box, deliver, diagram, group, icon, ref, same_rank, step, vault_ns, vso_ns

with diagram("entity-secrets", direction="TB"):
    with group("Onboarding · task config:entity-secret", YELLOW, YELLOW_FILL):
        catalogue = box("apps.json", "app → team, business_unit")
        script = icon(Bash, "config-entity-secret.sh")

    with vso_ns():
        op = icon(ControllerManager, "VSO controller")

    apps = []
    for i, (title, sa_name) in enumerate(
        (("entity-app-1", "entity-app-1-sa"), ("entity-app-2 / entity-app-3", "entity-app-N-sa"))
    ):
        with app_ns(title):
            sa = icon(ServiceAccount, "ServiceAccount", sa_name)
            vss = icon(CRD, "VaultStaticSecret", "vault-kv-app", group=f"crd{i}")
            auth = icon(CRD, "VaultAuth", "entity-auth", group=f"crd{i}")
            sec = icon(Secret, "Secret", "secretkv", group=f"sec{i}")
            dep = icon(Deployment, "Deployment", "entity-app", group=f"sec{i}")
        vss >> ref("vaultAuthRef") >> auth
        apps.append((sa, vss, auth, sec, dep))

    with vault_ns():
        role = icon(Vault, "auth/jwt", "role: entity-secret\nuser_claim: SA name")
        alias = box("Entity alias", "entity-app-N-sa")
        entity = box("Entity entity-app-N", "metadata: application_name,\nteam, business_unit, namespace")
        policy = box("policy entity-secret", "kvv2/data/teams/{{identity.entity.metadata.team}}/*")
        kv = box("kvv2/teams/&lt;team&gt;/config", "payments · risk")

    catalogue >> ref() >> script
    script >> ref("pre-create") >> entity
    script >> ref("pre-create") >> alias
    alias >> ref() >> entity
    # Grid (TB): one row for SA / resource / Secret, one row for VaultAuth / Deployment
    same_rank(*[n for a in apps for n in (a[0], a[1], a[3])])
    same_rank(*[n for a in apps for n in (a[2], a[4])])
    same_rank(entity, policy)
    for sa, _vss, auth, sec, dep in apps:
        op >> step(1, "TokenRequest") >> sa
        auth >> step(2, "JWT login") >> role
        op >> deliver(5, "sync") >> sec >> deliver() >> dep
    role >> step(3, "match alias") >> alias
    entity >> step(4, "team metadata") >> policy >> kv
