path "db/creds/dev-postgres" {
	capabilities = ["read"]
}

path "pki/issue/example-dot-com" {
	capabilities = ["create", "update"]
}
