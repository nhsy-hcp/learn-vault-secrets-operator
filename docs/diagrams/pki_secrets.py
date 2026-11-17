"""PKI lab: cert-manager Certificate signed by the VSO VaultClusterIssuer."""

from diagrams.k8s.compute import Deployment
from diagrams.k8s.others import CRD
from diagrams.k8s.podconfig import Secret
from diagrams.k8s.rbac import ServiceAccount
from diagrams.onprem.certificates import CertManager
from diagrams.onprem.security import Vault

from common import app_ns, box, deliver, diagram, icon, note, ref, same_rank, step, vault_ns, vso_ns

# Grid (TB): one row per namespace (app · VSO · Vault); columns line up the hand-offs
with diagram("pki-secrets", direction="TB"):
    with vault_ns():
        role = icon(Vault, "auth/kubernetes", "role: pki-secret\nannotations → alias metadata", group="c2")
        policy = box("policy pki-secret", "pki/sign/{{…metadata.pki_role}}", group="c3")
        pki = box("pki/roles/pki-cluster-issuer", "allowed_domains: pki-app-*", group="c4")

    with app_ns("pki-app-N · one Certificate per namespace"):
        cert = icon(CertManager, "Certificate", "pki-app-cert", group="c1")
        tls = icon(Secret, "Secret", "pki-app-tls\nkubernetes.io/tls", group="c2")
        app = icon(Deployment, "Deployment", "pki-app · /etc/tls", group="c3")

    with vso_ns("vault-secrets-operator · cluster-scoped issuer"):
        issuer = icon(CRD, "VaultClusterIssuer", "vault-pki", group="c1")
        auth = icon(CRD, "VaultAuth", "pki-issuer-auth", group="c2")
        sa = icon(ServiceAccount, "ServiceAccount", "pki-issuer-sa\nalias-metadata-pki_role", group="c3")

    takeaway = note("One shared issuer: any namespace can request<br/>any pki-app-* name (lab trade-off)")

    same_rank(cert, tls, app, takeaway)
    same_rank(issuer, auth, sa)
    same_rank(role, policy, pki)

    cert >> step(1, "CertificateRequest") >> issuer
    issuer >> step(2) >> auth
    auth >> step(3, "kubernetes login") >> role
    # back-reference to the row above: must not influence ranking
    role >> ref("TokenReview +<br/>read SA annotations", n=4, constraint="false") >> sa
    role >> step(5) >> policy >> pki
    cert >> deliver(6, "signed cert + key") >> tls >> deliver() >> app
