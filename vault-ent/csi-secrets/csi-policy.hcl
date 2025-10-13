path "kvv2/data/db-creds" {
  capabilities = ["read"]
}

path "pki/issue/example-dot-com" {
  capabilities = ["create", "update"]
}

path "sys/license/status" {
  capabilities = ["read"]
}
