#!/bin/bash
set -euo pipefail

CLUSTER_NAME="${1:?Usage: cluster-up.sh <cluster-name>}"

cluster_exists() {
  k3d cluster list --no-headers 2>/dev/null | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"
}

if cluster_exists; then
  echo "Cluster '${CLUSTER_NAME}' already exists - starting if stopped."
  k3d cluster start "${CLUSTER_NAME}" 2>/dev/null || true
else
  echo "Creating cluster '${CLUSTER_NAME}'..."
  # --wait=false: Podman's journald log driver causes log-read failures during wait.
  # cluster-ready.sh handles the readiness gate via kubectl instead.
  # Vault is exposed on localhost:8200 via NodePort 30820 (set by task install:vault).
  # anonymous-auth: k3s disables it by default; Vault's JWT auth fetches OIDC discovery
  # unauthenticated (scoped by the oidc-discovery-public ClusterRoleBinding).
  k3d cluster create "${CLUSTER_NAME}" \
    --wait=false \
    --port 8200:30820@server:0 \
    --k3s-arg "--disable=traefik,servicelb@server:0" \
    --k3s-arg "--kube-apiserver-arg=anonymous-auth=true@server:0"
fi

# Always sync kubeconfig and switch context
k3d kubeconfig merge "${CLUSTER_NAME}" --kubeconfig-merge-default --kubeconfig-switch-context
echo "cluster-up complete."
