"""CSI lab: the VSO CSI driver mounts Vault KV values into a tmpfs volume (no Kubernetes Secret)."""

from diagrams.k8s.compute import DaemonSet, Pod
from diagrams.k8s.others import CRD
from diagrams.k8s.rbac import ServiceAccount
from diagrams.k8s.storage import Volume
from diagrams.onprem.security import Vault

from common import app_ns, box, deliver, diagram, icon, note, ref, same_rank, step, vault_ns, vso_ns

# Grid (LR): driver · CSISecrets / volume / Vault auth · VaultAuth / Pod / KV · ServiceAccount / note
with diagram("csi-secrets", direction="LR"):
    with vso_ns():
        drv = icon(DaemonSet, "VSO CSI driver", "csi.vso.hashicorp.com")

    with app_ns("csi-app"):
        cs = icon(CRD, "CSISecrets", "csi-demo", group="crd")
        auth = icon(CRD, "VaultAuth", "csi-auth", group="crd")
        sa = icon(ServiceAccount, "ServiceAccount", "csi-app-sa", group="crd")
        vol = icon(Volume, "tmpfs volume", "/secrets/static", group="vol")
        pod = icon(Pod, "Pod", "csi-app", group="vol")

    with vault_ns():
        role = icon(Vault, "auth/k8s-auth-mount", "role: csi-secret", group="vault")
        kv = box("kvv2/db-creds", "KV v2", group="vault")

    takeaway = note("No Kubernetes Secret is created:<br/>values only exist in the pod's tmpfs volume")

    same_rank(cs, vol, role)
    same_rank(auth, pod, kv)
    same_rank(sa, takeaway)

    pod >> step(1, "CSI volume") >> drv
    drv >> step(2, "reads") >> cs
    cs >> ref("vaultAuthRef") >> auth
    auth >> ref("uses") >> sa
    drv >> step(3, "JWT login") >> role
    role >> step(4) >> kv
    drv >> deliver(5, "write files") >> vol
    vol >> ref("mounted into") >> pod
