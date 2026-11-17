"""Static secrets lab: VaultStaticSecret syncs kvv2/webapp/config into each static-app-* namespace."""

from diagrams.k8s.compute import Pod
from diagrams.k8s.controlplane import ControllerManager
from diagrams.k8s.others import CRD
from diagrams.k8s.podconfig import Secret
from diagrams.onprem.security import Vault

from common import app_ns, box, deliver, diagram, icon, ref, same_rank, step, vault_ns, vso_ns

# Grid (LR): VSO · resources / Secrets · VaultAuth / Pods · Vault auth · KV
with diagram("static-secrets", direction="LR"):
    with vso_ns():
        op = icon(ControllerManager, "VSO controller")

    apps = []
    for i, title in enumerate(("static-app-1", "static-app-2 / static-app-3")):
        with app_ns(title):
            vss = icon(CRD, "VaultStaticSecret", "vault-kv-app", group=f"crd{i}")
            auth = icon(CRD, "VaultAuth", "static-auth", group=f"crd{i}")
            sec = icon(Secret, "Secret", "secretkv", group=f"sec{i}")
            pod = icon(Pod, "Pod", "static-app", group=f"sec{i}")
        apps.append((vss, auth, sec, pod))

    with vault_ns():
        role = icon(Vault, "auth/jwt", "role: static-secret\nbound ns glob: static-app-*", group="vault")
        kv = box("kvv2/webapp/config", "KV v2", group="vault")

    same_rank(*[a[0] for a in apps], *[a[2] for a in apps])
    same_rank(*[a[1] for a in apps], *[a[3] for a in apps])

    for vss, auth, sec, pod in apps:
        vss >> ref("vaultAuthRef") >> auth
        op >> step(1, "watches") >> vss
        auth >> step(2, "JWT login") >> role
        op >> deliver(4, "sync") >> sec >> deliver() >> pod
    role >> step(3, "read") >> kv
