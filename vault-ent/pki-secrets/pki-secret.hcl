# pki_role comes from the issuer service account annotation vault.hashicorp.com/alias-metadata-pki_role,
# so the VaultClusterIssuer can only use its own PKI role. __ACCESSOR__ is replaced at config time.
# cert-manager generates the key and submits a CSR, which VSO signs via pki/sign (no pki/issue needed).
path "pki/sign/{{identity.entity.aliases.__ACCESSOR__.metadata.pki_role}}" {
  capabilities = ["create", "update"]
}

# VaultIssuer/VaultClusterIssuer check the Vault Enterprise license before becoming Ready
path "sys/license/status" {
  capabilities = ["read"]
}
