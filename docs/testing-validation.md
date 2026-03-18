# Testing and Validation Guide

## Overview

This guide provides comprehensive testing and validation procedures for HashiCorp Vault and Vault Secrets Operator (VSO) deployments on Kubernetes. It covers automated tests, manual validation checklists, and integration testing scenarios.

## Automated Testing

### Quick Validation

```bash
# Run complete validation suite
task verify

# This executes:
# - Pod health checks
# - Static secret validation
# - Dynamic secret validation
# - CSI secret validation
```

### Individual Component Tests

```bash
# Verify pod status
task verify:pods

# Verify static secrets
task verify:static-secret

# Verify dynamic secrets
task verify:dynamic-secret

# Verify CSI secrets
task verify:csi-secret
```

## Manual Validation Checklist

### Pre-Deployment Validation

#### Infrastructure Readiness

**Minikube:**
- [ ] Minikube cluster is running
- [ ] Sufficient resources allocated (4 CPU, 8GB RAM minimum)
- [ ] Storage provisioner is active
- [ ] kubectl context is set to minikube

**EKS:**
- [ ] EKS cluster is created and accessible
- [ ] Node groups are healthy and running
- [ ] EBS CSI driver is installed
- [ ] AWS Load Balancer Controller is running
- [ ] kubectl context is set to EKS cluster

**GKE:**
- [ ] GKE cluster is created and accessible
- [ ] Node pools are healthy and running
- [ ] Persistent Disk CSI driver is available
- [ ] kubectl context is set to GKE cluster

#### Prerequisites Check

```bash
# Verify all required tools
task prerequisites

# Expected output:
# ✓ kubectl version 1.x.x
# ✓ helm version 3.x.x
# ✓ task version 3.x.x
# ✓ jq version 1.x.x
# ✓ Platform-specific tools (aws/gcloud/minikube)
```

- [ ] All required tools are installed
- [ ] Tool versions meet minimum requirements
- [ ] Vault Enterprise license file exists at `vault-ent/vault-license.lic`
- [ ] License file is valid and not expired

### Vault Installation Validation

#### Vault Pods

```bash
# Check Vault pod status
kubectl get pods -n vault

# Expected output:
# NAME                                    READY   STATUS    RESTARTS   AGE
# vault-0                                 1/1     Running   0          2m
# vault-agent-injector-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

**Checklist:**
- [ ] Vault pod (vault-0) is in Running state
- [ ] Vault agent injector is in Running state
- [ ] No pods are in CrashLoopBackOff or Error state
- [ ] Pods have 0 restarts (or minimal restarts)

#### Vault Storage

```bash
# Check PVC status
kubectl get pvc -n vault

# Expected output:
# NAME           STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# data-vault-0   Bound    pvc-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx   10Gi       RWO            <class>        2m
```

**Checklist:**
- [ ] PVC is in Bound state
- [ ] Volume is created and attached
- [ ] Storage class is correct for platform (standard/gp2/standard-rwo)
- [ ] Capacity is 10Gi

#### Vault Status

```bash
# Check Vault seal status
kubectl exec -n vault vault-0 -- vault status

# Expected output includes:
# Sealed: false
# Initialized: true
# HA Enabled: false
```

**Checklist:**
- [ ] Vault is initialized
- [ ] Vault is unsealed
- [ ] Vault version is correct
- [ ] Storage backend is raft

#### Vault Service

```bash
# Check Vault service
kubectl get svc -n vault vault

# Expected output:
# NAME    TYPE           CLUSTER-IP      EXTERNAL-IP     PORT(S)
# vault   LoadBalancer   10.x.x.x        <pending/IP>    8200:xxxxx/TCP,8201:xxxxx/TCP
```

**Checklist:**
- [ ] Service is created
- [ ] Service type is LoadBalancer
- [ ] Ports 8200 and 8201 are exposed
- [ ] External IP is assigned (or accessible via tunnel/port-forward)

### VSO Installation Validation

#### VSO Pods

```bash
# Check VSO pod status
kubectl get pods -n vault-secrets-operator

# Expected output:
# NAME                                                        READY   STATUS    RESTARTS   AGE
# vault-secrets-operator-controller-manager-xxxxxxxxx-xxxxx   2/2     Running   0          1m
```

**Checklist:**
- [ ] VSO controller pod is in Running state
- [ ] Pod shows 2/2 containers ready
- [ ] No restarts or errors

#### VSO CRDs

```bash
# Check CRDs are installed
kubectl get crd | grep vault

# Expected output includes:
# vaultauths.secrets.hashicorp.com
# vaultconnections.secrets.hashicorp.com
# vaultdynamicsecrets.secrets.hashicorp.com
# vaultstaticsecrets.secrets.hashicorp.com
```

**Checklist:**
- [ ] VaultAuth CRD is installed
- [ ] VaultConnection CRD is installed
- [ ] VaultStaticSecret CRD is installed
- [ ] VaultDynamicSecret CRD is installed

### Vault Configuration Validation

#### Namespaces

```bash
# List Vault namespaces
kubectl exec -n vault vault-0 -- vault namespace list

# Expected output:
# vso/
# tn001/
```

**Checklist:**
- [ ] `vso` namespace exists
- [ ] `tn001` namespace exists

#### Secret Engines

```bash
# List secret engines in tn001
kubectl exec -n vault vault-0 -- vault secrets list -namespace=tn001

# Expected output includes:
# kvv2/
# db/
# pki/
```

**Checklist:**
- [ ] KV v2 engine mounted at `kvv2/`
- [ ] Database engine mounted at `db/`
- [ ] PKI engine mounted at `pki/`

```bash
# List secret engines in vso
kubectl exec -n vault vault-0 -- vault secrets list -namespace=vso

# Expected output includes:
# vso-transit/
```

**Checklist:**
- [ ] Transit engine mounted at `vso-transit/`

#### Authentication

```bash
# List auth methods in tn001
kubectl exec -n vault vault-0 -- vault auth list -namespace=tn001

# Expected output includes:
# k8s-auth-mount/
```

**Checklist:**
- [ ] Kubernetes auth method mounted at `k8s-auth-mount/`

```bash
# Check Kubernetes auth configuration
kubectl exec -n vault vault-0 -- vault read -namespace=tn001 auth/k8s-auth-mount/config

# Expected output includes:
# kubernetes_host
# token_reviewer_jwt
```

**Checklist:**
- [ ] Kubernetes host is configured
- [ ] JWT token reviewer is configured

#### Policies

```bash
# List policies in tn001
kubectl exec -n vault vault-0 -- vault policy list -namespace=tn001

# Expected output includes:
# static-secret
# dynamic-secret
# csi-secret
```

**Checklist:**
- [ ] `static-secret` policy exists
- [ ] `dynamic-secret` policy exists
- [ ] `csi-secret` policy exists

#### Roles

```bash
# List Kubernetes auth roles in tn001
kubectl exec -n vault vault-0 -- vault list -namespace=tn001 auth/k8s-auth-mount/role

# Expected output includes:
# static-secret
# dynamic-secret
# csi-secret
```

**Checklist:**
- [ ] `static-secret` role exists
- [ ] `dynamic-secret` role exists
- [ ] `csi-secret` role exists

### Static Secrets Validation

#### Namespace and Resources

```bash
# Check static app namespaces
kubectl get namespaces | grep static-app

# Expected output:
# static-app-1
# static-app-2
# static-app-3
```

**Checklist:**
- [ ] All static app namespaces exist (static-app-1, static-app-2, static-app-3)

```bash
# Check VaultAuth resources
kubectl get vaultauth -n static-app-1

# Expected output:
# NAME          AGE
# static-auth   1m
```

**Checklist:**
- [ ] VaultAuth resource exists in each namespace
- [ ] VaultAuth status shows "Accepted"

```bash
# Check VaultStaticSecret resources
kubectl get vaultstaticsecret -n static-app-1

# Expected output:
# NAME            AGE
# vault-kv-app    1m
```

**Checklist:**
- [ ] VaultStaticSecret resource exists in each namespace
- [ ] VaultStaticSecret status shows secret is synced

#### Secret Sync

```bash
# Check Kubernetes secret was created
kubectl get secret secretkv -n static-app-1

# Expected output:
# NAME       TYPE     DATA   AGE
# secretkv   Opaque   3      1m
```

**Checklist:**
- [ ] Kubernetes Secret `secretkv` exists in each namespace
- [ ] Secret contains expected keys (username, password, api_key)

```bash
# Verify secret content
kubectl get secret secretkv -n static-app-1 -o jsonpath='{.data}' | jq 'keys'

# Expected output:
# ["api_key", "password", "username"]
```

**Checklist:**
- [ ] Secret contains `username` key
- [ ] Secret contains `password` key
- [ ] Secret contains `api_key` key

#### Application Pods

```bash
# Check application pods
kubectl get pods -n static-app-1 -l app=static-app

# Expected output:
# NAME                          READY   STATUS    RESTARTS   AGE
# static-app-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
```

**Checklist:**
- [ ] Application pod is running in each namespace
- [ ] Pod has no restarts

```bash
# Verify environment variables
kubectl exec -n static-app-1 -l app=static-app -- env | grep -E "USERNAME|PASSWORD|API_KEY"

# Expected output:
# USERNAME=demo-user
# PASSWORD=super-secret-password
# API_KEY=abc123xyz789
```

**Checklist:**
- [ ] Environment variables are set correctly
- [ ] Values match Vault secret

```bash
# Verify volume mount
kubectl exec -n static-app-1 -l app=static-app -- ls -la /secrets/static

# Expected output:
# username
# password
# api_key
```

**Checklist:**
- [ ] Secrets are mounted at `/secrets/static`
- [ ] All secret keys are present as files

### Dynamic Secrets Validation

#### Namespace and Resources

```bash
# Check dynamic app namespace
kubectl get namespace dynamic-app

# Check VaultAuth resource
kubectl get vaultauth -n dynamic-app

# Expected output:
# NAME           AGE
# dynamic-auth   1m
```

**Checklist:**
- [ ] `dynamic-app` namespace exists
- [ ] VaultAuth resource exists
- [ ] VaultAuth status shows "Accepted"

```bash
# Check VaultDynamicSecret resources
kubectl get vaultdynamicsecret -n dynamic-app

# Expected output:
# NAME            AGE
# vso-db-demo     1m
# vso-pki-demo    1m
```

**Checklist:**
- [ ] VaultDynamicSecret `vso-db-demo` exists
- [ ] VaultDynamicSecret `vso-pki-demo` exists
- [ ] Both resources show secrets are synced

#### Database Credentials

```bash
# Check database secret was created
kubectl get secret vso-db-demo -n dynamic-app

# Expected output:
# NAME           TYPE     DATA   AGE
# vso-db-demo    Opaque   2      1m
```

**Checklist:**
- [ ] Kubernetes Secret `vso-db-demo` exists
- [ ] Secret contains username and password

```bash
# Verify secret content
kubectl get secret vso-db-demo -n dynamic-app -o jsonpath='{.data}' | jq 'keys'

# Expected output:
# ["password", "username"]
```

**Checklist:**
- [ ] Secret contains `username` key
- [ ] Secret contains `password` key

#### PKI Certificates

```bash
# Check PKI secret was created
kubectl get secret vso-pki-demo -n dynamic-app

# Expected output:
# NAME            TYPE     DATA   AGE
# vso-pki-demo    Opaque   5      1m
```

**Checklist:**
- [ ] Kubernetes Secret `vso-pki-demo` exists
- [ ] Secret contains certificate data

```bash
# Verify secret content
kubectl get secret vso-pki-demo -n dynamic-app -o jsonpath='{.data}' | jq 'keys'

# Expected output includes:
# ["certificate", "issuing_ca", "private_key", "serial_number"]
```

**Checklist:**
- [ ] Secret contains `certificate` key
- [ ] Secret contains `private_key` key
- [ ] Secret contains `issuing_ca` key

#### Application Pods

```bash
# Check application pods
kubectl get pods -n dynamic-app -l app=dynamic-app

# Expected output:
# NAME                           READY   STATUS    RESTARTS   AGE
# dynamic-app-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
```

**Checklist:**
- [ ] Application pod is running
- [ ] Pod has no restarts

```bash
# Verify database credentials are mounted
kubectl exec -n dynamic-app -l app=dynamic-app -- ls -la /secrets/dynamic/db

# Expected output:
# username
# password
```

**Checklist:**
- [ ] Database credentials are mounted at `/secrets/dynamic/db`
- [ ] Username and password files exist

```bash
# Verify PKI certificates are mounted
kubectl exec -n dynamic-app -l app=dynamic-app -- ls -la /secrets/dynamic/tls

# Expected output:
# certificate
# private_key
# issuing_ca
```

**Checklist:**
- [ ] PKI certificates are mounted at `/secrets/dynamic/tls`
- [ ] Certificate, private key, and CA files exist

#### PostgreSQL Database

```bash
# Check PostgreSQL pod
kubectl get pods -n dynamic-app -l app=postgres

# Expected output:
# NAME                        READY   STATUS    RESTARTS   AGE
# postgres-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
```

**Checklist:**
- [ ] PostgreSQL pod is running
- [ ] Pod has no restarts

```bash
# Test database connection with dynamic credentials
export DB_USER=$(kubectl get secret vso-db-demo -n dynamic-app -o jsonpath='{.data.username}' | base64 -d)
export DB_PASS=$(kubectl get secret vso-db-demo -n dynamic-app -o jsonpath='{.data.password}' | base64 -d)

kubectl exec -n dynamic-app -l app=postgres -- psql -U $DB_USER -d postgres -c "SELECT 1;"

# Expected output:
# ?column?
# ----------
#        1
```

**Checklist:**
- [ ] Can connect to database with dynamic credentials
- [ ] Credentials have appropriate permissions

### CSI Secrets Validation

#### Namespace and Resources

```bash
# Check CSI app namespace
kubectl get namespace csi-app

# Check SecretProviderClass
kubectl get secretproviderclass -n csi-app

# Expected output:
# NAME             AGE
# vault-database   1m
```

**Checklist:**
- [ ] `csi-app` namespace exists
- [ ] SecretProviderClass `vault-database` exists

#### CSI Provider

```bash
# Check CSI provider pods
kubectl get pods -n vault -l app.kubernetes.io/name=vault-csi-provider

# Expected output:
# NAME                                  READY   STATUS    RESTARTS   AGE
# vault-csi-provider-xxxxxxxxxx-xxxxx   1/1     Running   0          5m
```

**Checklist:**
- [ ] CSI provider pod is running
- [ ] Pod has no restarts

#### Application Pods

```bash
# Check application pods
kubectl get pods -n csi-app -l app=csi-app

# Expected output:
# NAME                       READY   STATUS    RESTARTS   AGE
# csi-app-xxxxxxxxxx-xxxxx   1/1     Running   0          1m
```

**Checklist:**
- [ ] Application pod is running
- [ ] Pod has no restarts

```bash
# Verify CSI volume is mounted
kubectl exec -n csi-app -l app=csi-app -- ls -la /secrets/static

# Expected output:
# db-password
# db-username
```

**Checklist:**
- [ ] CSI volume is mounted at `/secrets/static`
- [ ] Secret files exist (db-username, db-password)

```bash
# Verify secret content
kubectl exec -n csi-app -l app=csi-app -- cat /secrets/static/db-username
kubectl exec -n csi-app -l app=csi-app -- cat /secrets/static/db-password

# Expected output:
# <username>
# <password>
```

**Checklist:**
- [ ] Secret files contain expected values
- [ ] Values match Vault secret

```bash
# Verify NO Kubernetes Secret was created (CSI direct mount)
kubectl get secret -n csi-app | grep -v "default-token"

# Expected output:
# (should not show any application secrets)
```

**Checklist:**
- [ ] No Kubernetes Secret resource created for CSI secrets
- [ ] Secrets only exist in pod filesystem

## Integration Testing

### End-to-End Static Secret Flow

```bash
# 1. Update secret in Vault
kubectl exec -n vault vault-0 -- vault kv put -namespace=tn001 kvv2/webapp/config \
  username=updated-user \
  password=updated-password \
  api_key=updated-key

# 2. Wait for VSO to sync (default: 5 minutes, or trigger manually)
kubectl delete pod -n static-app-1 -l app=static-app

# 3. Verify updated secret in Kubernetes
kubectl get secret secretkv -n static-app-1 -o jsonpath='{.data.username}' | base64 -d
# Expected: updated-user

# 4. Verify application receives updated secret
kubectl exec -n static-app-1 -l app=static-app -- env | grep USERNAME
# Expected: USERNAME=updated-user
```

### End-to-End Dynamic Secret Flow

```bash
# 1. Check current credentials
export OLD_USER=$(kubectl get secret vso-db-demo -n dynamic-app -o jsonpath='{.data.username}' | base64 -d)

# 2. Force credential rotation by deleting secret
kubectl delete secret vso-db-demo -n dynamic-app

# 3. Wait for VSO to generate new credentials
sleep 10

# 4. Verify new credentials
export NEW_USER=$(kubectl get secret vso-db-demo -n dynamic-app -o jsonpath='{.data.username}' | base64 -d)

# 5. Verify credentials are different
echo "Old: $OLD_USER"
echo "New: $NEW_USER"
# Expected: Different usernames

# 6. Test new credentials work
export DB_PASS=$(kubectl get secret vso-db-demo -n dynamic-app -o jsonpath='{.data.password}' | base64 -d)
kubectl exec -n dynamic-app -l app=postgres -- psql -U $NEW_USER -d postgres -c "SELECT 1;"
# Expected: Success
```

### End-to-End CSI Secret Flow

```bash
# 1. Update secret in Vault
kubectl exec -n vault vault-0 -- vault kv put -namespace=tn001 kvv2/db-creds \
  db-username=csi-updated-user \
  db-password=csi-updated-password

# 2. Restart pod to remount CSI volume
kubectl delete pod -n csi-app -l app=csi-app

# 3. Wait for pod to restart
kubectl wait --for=condition=ready pod -n csi-app -l app=csi-app --timeout=60s

# 4. Verify updated secret
kubectl exec -n csi-app -l app=csi-app -- cat /secrets/static/db-username
# Expected: csi-updated-user
```

### Authentication Testing

```bash
# Test static secret authentication
kubectl exec -n vault vault-0 -- vault write -namespace=tn001 auth/k8s-auth-mount/login \
  role=static-secret \
  jwt=$(kubectl get secret -n static-app-1 $(kubectl get sa static-app-sa -n static-app-1 -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d)

# Expected: Success with token

# Test dynamic secret authentication
kubectl exec -n vault vault-0 -- vault write -namespace=tn001 auth/k8s-auth-mount/login \
  role=dynamic-secret \
  jwt=$(kubectl get secret -n dynamic-app $(kubectl get sa dynamic-app-sa -n dynamic-app -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d)

# Expected: Success with token

# Test CSI secret authentication
kubectl exec -n vault vault-0 -- vault write -namespace=tn001 auth/k8s-auth-mount/login \
  role=csi-secret \
  jwt=$(kubectl get secret -n csi-app $(kubectl get sa csi-app-sa -n csi-app -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 -d)

# Expected: Success with token
```

### Policy Testing

```bash
# Test static secret policy allows read
kubectl exec -n vault vault-0 -- vault kv get -namespace=tn001 kvv2/webapp/config
# Expected: Success

# Test static secret policy denies write (should fail)
kubectl exec -n vault vault-0 -- vault kv put -namespace=tn001 kvv2/webapp/config test=value
# Expected: Permission denied

# Test dynamic secret policy allows credential generation
kubectl exec -n vault vault-0 -- vault read -namespace=tn001 db/creds/dev-postgres
# Expected: Success with credentials
```

## Performance Testing

### Secret Sync Performance

```bash
# Measure time to sync static secrets
time kubectl apply -f vault-ent/static-secrets/templates/static-secret.yaml.tpl

# Measure time for secret to appear in Kubernetes
time until kubectl get secret secretkv -n static-app-1 2>/dev/null; do sleep 1; done

# Expected: < 10 seconds
```

### Dynamic Secret Generation Performance

```bash
# Measure time to generate database credentials
time kubectl apply -f vault-ent/dynamic-secrets/dynamic-db-secret.yaml

# Measure time for credentials to appear
time until kubectl get secret vso-db-demo -n dynamic-app 2>/dev/null; do sleep 1; done

# Expected: < 15 seconds
```

### VSO Cache Performance

```bash
# Enable VSO caching
kubectl patch vaultauth static-auth -n static-app-1 --type=merge -p '
spec:
  storageEncryption:
    mount: vso-transit
    keyName: vso-client-cache
'

# Measure cache hit rate from VSO logs
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator | grep -i cache

# Expected: Cache hit rate > 70%
```

## Stress Testing

### Multiple Secret Syncs

```bash
# Create multiple static app instances
for i in {4..10}; do
  kubectl create namespace static-app-$i
  kubectl apply -f vault-ent/static-secrets/templates/ -n static-app-$i
done

# Verify all secrets sync successfully
for i in {1..10}; do
  kubectl get secret secretkv -n static-app-$i
done

# Expected: All secrets exist
```

### Rapid Secret Updates

```bash
# Update secret rapidly
for i in {1..10}; do
  kubectl exec -n vault vault-0 -- vault kv put -namespace=tn001 kvv2/webapp/config \
    username=user-$i \
    password=pass-$i \
    api_key=key-$i
  sleep 5
done

# Verify VSO keeps up with updates
kubectl logs -n vault-secrets-operator -l app.kubernetes.io/name=vault-secrets-operator | grep -i error

# Expected: No errors
```

## Validation Summary

### Quick Validation Script

```bash
#!/bin/bash
# save as validate-deployment.sh

echo "=== Vault Validation ==="
kubectl get pods -n vault
kubectl exec -n vault vault-0 -- vault status

echo "=== VSO Validation ==="
kubectl get pods -n vault-secrets-operator
kubectl get crd | grep vault

echo "=== Static Secrets Validation ==="
kubectl get vaultstaticsecret -A
kubectl get secret secretkv -n static-app-1

echo "=== Dynamic Secrets Validation ==="
kubectl get vaultdynamicsecret -A
kubectl get secret vso-db-demo -n dynamic-app
kubectl get secret vso-pki-demo -n dynamic-app

echo "=== CSI Secrets Validation ==="
kubectl get secretproviderclass -n csi-app
kubectl exec -n csi-app -l app=csi-app -- ls -la /secrets/static

echo "=== All Validations Complete ==="
```

## Troubleshooting Failed Validations

If any validation fails, refer to the [Troubleshooting Guide](troubleshooting.md) for detailed debugging procedures.

### Common Validation Failures

1. **Pods not running**: Check events and logs
2. **Secrets not syncing**: Verify VaultAuth and policies
3. **Authentication failures**: Check JWT token reviewer and roles
4. **CSI mount failures**: Verify CSI provider and SecretProviderClass

## Additional Resources

- [Vault Testing Guide](https://developer.hashicorp.com/vault/docs/testing)
- [VSO Testing](https://github.com/hashicorp/vault-secrets-operator/tree/main/test)
- [Kubernetes Testing](https://kubernetes.io/docs/tasks/debug/)
