"""High-level view: Vault Enterprise, VSO, cert-manager and the demo namespaces."""

from diagrams.k8s.controlplane import ControllerManager
from diagrams.onprem.certificates import CertManager
from diagrams.onprem.security import Vault

from common import GREY, app_ns, box, deliver, diagram, group, icon, ref, same_rank, step, vault_ns, vso_ns

# Grid (LR): cert-manager / VSO · application namespaces (one column) · Vault
with diagram("architecture", direction="LR"):
    with group("Kubernetes cluster (k3d · EKS · GKE)", GREY, "white"):
        with group("cert-manager", "#0f766e", "#f0fdfa"):
            cm = icon(CertManager, "cert-manager", "Certificates via\nVaultClusterIssuer")
        with vso_ns():
            vso = icon(ControllerManager, "Vault Secrets Operator", "watches VSO resources\nsyncs Secrets / CSI volumes")
        with app_ns("Application namespaces"):
            agent = box("vault-agent-app", "Vault Agent init container (optional)")
            static = box("static-app-*", "VaultStaticSecret")
            dynamic = box("dynamic-app", "VaultDynamicSecret · VaultPKISecret")
            csi = box("csi-app", "CSISecrets (CSI volume)")
            entity = box("entity-app-*", "VaultStaticSecret (entity metadata)")
            pki = box("pki-app-*", "cert-manager Certificate")
        with vault_ns("vault"):
            vault = icon(Vault, "Vault Enterprise", "namespaces: vso, tn001")

    same_rank(cm, vso)
    same_rank(agent, static, dynamic, csi, entity, pki)

    cm >> step(2, "sign CSRs via VSO") >> vso
    vso >> step(1, "log in, read / issue") >> vault
    for ns in (static, dynamic, csi, entity):
        vso >> deliver(3, "sync") >> ns
    cm >> deliver(3, "issue") >> pki
    agent >> ref("direct login") >> vault
