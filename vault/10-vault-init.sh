#!/bin/bash

set -o pipefail

kubectl wait --for=jsonpath='{.status.phase}'=Running pod --all --namespace vault --timeout=1m
sleep 3
kubectl exec -n vault -ti vault-0 -- vault version
kubectl exec -n vault -ti vault-0 -- vault status
kubectl exec -n vault -ti vault-0 -- vault operator init -format=json | tee vault-init.json
kubectl exec -n vault -ti vault-0 -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[0]')
kubectl exec -n vault -ti vault-0 -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[1]')
kubectl exec -n vault -ti vault-0 -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[2]')
kubectl exec -n vault -ti vault-0 -- vault status
sleep 3
kubectl exec -n vault -ti vault-1 -- vault version
kubectl exec -n vault -ti vault-1 -- vault status
kubectl exec -n vault -ti vault-1 -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[0]')
kubectl exec -n vault -ti vault-1 -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[1]')
kubectl exec -n vault -ti vault-1 -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[2]')
kubectl exec -n vault -ti vault-1 -- vault status

kubectl exec -n vault -ti vault-2 -- vault version
kubectl exec -n vault -ti vault-2 -- vault status
kubectl exec -n vault -ti vault-2 -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[0]')
kubectl exec -n vault -ti vault-2 -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[1]')
kubectl exec -n vault -ti vault-2 -- vault operator unseal $(cat vault-init.json | jq -r '.unseal_keys_b64[2]')
kubectl exec -n vault -ti vault-2 -- vault status
sleep 3
kubectl exec -n vault -ti vault-0 -- /bin/sh -c "VAULT_TOKEN=$(cat vault-init.json | jq -r '.root_token') vault operator raft list-peers"
