"""Vault Agent lab (optional): an init container renders the secret into a shared emptyDir."""

from diagrams.k8s.compute import Pod
from diagrams.k8s.podconfig import ConfigMap
from diagrams.k8s.rbac import ServiceAccount
from diagrams.k8s.storage import Volume
from diagrams.onprem.security import Vault

from common import BLUE, BLUE_FILL, app_ns, box, deliver, diagram, group, icon, note, ref, same_rank, step, vault_ns

# Grid (LR): column 1 inputs · column 2 agent / auth · column 3 volume / KV · column 4 app / note
with diagram("vault-agent-secrets", direction="LR"):
    with vault_ns():
        role = icon(Vault, "auth/jwt", "role: vault-agent-secret", group="vault")
        kv = box("kvv2/webapp/config", "KV v2", group="vault")

    with app_ns("vault-agent-app"):
        sa = icon(ServiceAccount, "ServiceAccount", "vault-agent-sa")
        cm = icon(ConfigMap, "ConfigMap", "vault-agent-config")
        with group("Pod vault-agent-app", BLUE, BLUE_FILL):
            init = icon(Vault, "initContainer", "vault-agent-init", group="pod")
            vol = icon(Volume, "emptyDir", "/vault/secrets", group="pod")
            app = icon(Pod, "container: app", "/vault/secrets/config.txt", group="pod")

    takeaway = note("No VSO custom resources:<br/>the agent logs in to Vault directly")

    same_rank(sa, cm)
    same_rank(init, role)
    same_rank(vol, kv)
    same_rank(app, takeaway)

    sa >> ref("projected JWT") >> init
    cm >> ref("agent config") >> init
    init >> deliver(3, "render template") >> vol >> deliver(4, "reads config.txt") >> app
    # external label: the edge midpoint sits on the namespace border
    init >> step(1, "JWT login", external=True) >> role
    role >> step(2, "read secret") >> kv
