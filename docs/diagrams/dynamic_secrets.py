"""Dynamic secrets lab: leased PostgreSQL credentials and a PKI certificate via VSO."""

from diagrams.k8s.compute import Pod
from diagrams.k8s.controlplane import ControllerManager
from diagrams.k8s.others import CRD
from diagrams.k8s.podconfig import Secret
from diagrams.onprem.database import PostgreSQL
from diagrams.onprem.security import Vault

from common import app_ns, box, deliver, diagram, icon, ref, same_rank, step, vault_ns, vso_ns

# Grid (TB): VSO · custom resources + synced Secrets · VaultAuth + Pod + PostgreSQL · Vault auth · engines
with diagram("dynamic-secrets", direction="TB"):
    with vso_ns():
        op = icon(ControllerManager, "VSO controller")

    with app_ns("dynamic-app"):
        vds = icon(CRD, "VaultDynamicSecret", "vso-db-demo", group="db")
        vps = icon(CRD, "VaultPKISecret", "vso-pki-demo")
        auth = icon(CRD, "VaultAuth", "dynamic-auth", group="db")
        sdb = icon(Secret, "Secret", "vso-db-demo", group="pod")
        stls = icon(Secret, "Secret", "vso-pki-demo\nkubernetes.io/tls")
        pod = icon(Pod, "Pod", "dynamic-app", group="pod")
        pg = icon(PostgreSQL, "PostgreSQL")

    with vault_ns():
        role = icon(Vault, "auth/jwt", "role: dynamic-secret", group="db")
        db = box("database/creds/dev-postgres", "short-lived user per lease", group="db")
        pki = box("pki/issue/example-dot-com", "TLS certificate")

    same_rank(vds, vps, sdb, stls)
    same_rank(auth, pod, pg)
    same_rank(db, pki)

    vds >> ref("vaultAuthRef") >> auth
    vps >> ref("vaultAuthRef") >> auth
    op >> step(1, "watches") >> vds
    op >> step(1, "watches") >> vps
    auth >> step(2, "JWT login") >> role
    role >> step(3) >> db
    role >> step(3) >> pki
    op >> deliver(4, "sync") >> sdb >> deliver() >> pod
    op >> deliver(4, "sync") >> stls >> deliver() >> pod
    pod >> deliver(5, "connect with issued creds") >> pg
