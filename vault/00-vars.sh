export VAULT_ADDR=http://127.0.0.1:8200
export VAULT_TOKEN=$(cat vault-init.json | jq -r '.root_token')

echo export VAULT_ADDR=$VAULT_ADDR
echo export VAULT_TOKEN=$VAULT_TOKEN
