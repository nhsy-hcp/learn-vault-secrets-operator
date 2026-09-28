# pki_role comes from the service account annotation vault.hashicorp.com/alias-metadata-pki_role,
# so each app can only issue from its own PKI role. __ACCESSOR__ is replaced at config time.
path "pki/issue/{{identity.entity.aliases.__ACCESSOR__.metadata.pki_role}}" {
  capabilities = ["create", "update"]
}
