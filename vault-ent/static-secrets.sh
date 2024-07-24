set -xe
vault namespace create us-west-org
sleep 20

export VAULT_NAMESPACE=us-west-org
vault auth enable -path demo-auth-mount kubernetes
sleep 20

vault write auth/demo-auth-mount/config \
		kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"


vault secrets enable -path=demo-transit transit
sleep 20

vault write -force demo-transit/keys/vso-client-cache
vault policy write demo-auth-policy-operator - <<EOF
path "demo-transit/encrypt/vso-client-cache" {
   capabilities = ["create", "update"]
}
path "demo-transit/decrypt/vso-client-cache" {
   capabilities = ["create", "update"]
}
EOF

vault write auth/demo-auth-mount/role/auth-role-operator \
   bound_service_account_names=vault-secrets-operator-controller-manager \
   bound_service_account_namespaces=vault-secrets-operator-system \
   token_ttl=0 \
   token_period=120 \
   token_policies=demo-auth-policy-operator \
   audience=vault

vault secrets enable -path=kvv2 kv-v2
sleep 20

vault policy write dev - <<EOF
path "kvv2/data/webapp/config" {
   capabilities = ["read", "list", "subscribe"]
   subscribe_event_types = ["kv*"]
}
path "sys/events/subscribe/kv*" {
   capabilities = ["read"]
}
EOF

vault write auth/demo-auth-mount/role/role1 \
		bound_service_account_names=demo-app \
		bound_service_account_namespaces=app \
		policies=dev \
		token_period=2m

vault kv put kvv2/webapp/config username="static-user" password="static-password"
