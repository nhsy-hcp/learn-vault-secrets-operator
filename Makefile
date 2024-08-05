all: k3d-create vault-prereqs vault-install svc-health
define header
	$(info Running >>> $(1)$(END))
endef

.PHONY: k3d-create
k3d-create:
	$(call header,$@)
	-@k3d cluster create vault -p "8200:30200@server:0" --k3s-arg "--disable=traefik@server:0" --k3s-arg "--disable=servicelb@server:0" --wait
	@sleep 3

.PHONY: destroy
destroy:
	$(call header,$@)
	@k3d cluster delete vault
	@sleep 3

.PHONY: vault-prereqs
vault-prereqs:
	$(call header,$@)
	@kubectl create ns vault
	@kubectl create secret generic vault-license --from-file license=vault-ent/vault-license.lic -n vault

.PHONY: vault-install
vault-install:
	$(call header,$@)
	@helm install vault hashicorp/vault -n vault --values vault-ent/vault-values.yaml --version 0.28.1
	@sleep 10
	@kubectl wait --for=jsonpath='{.status.phase}'=Running pod --all --namespace vault --timeout=1m
	@kubectl get all -n vault
	@kubectl exec -n vault -ti vault-0 -- vault audit enable file file_path=stdout
	@sleep 10

.PHONY: vault-init
vault-init:
	$(call header,$@)
	@./vault/10-vault-init.sh
	@sleep 10

.PHONY: vault-upgrade
vault-upgrade:
	$(call header,$@)
	@helm upgrade vault hashicorp/vault -n vault --values vault/my-values.yaml
	@sleep 10
	@kubectl wait --for=jsonpath='{.status.phase}'=Running pod --all --namespace vault --timeout=1m
	@kubectl get all -n vault

.PHONY: vault-uninstall
vault-uninstall:
	$(call header,$@)
	@helm uninstall vault -n vault
	@kubectl delete pvc -n vault --all
	@sleep 10

.PHONY: vault-reinstall
vault-reinstall: vault-uninstall vault-install

.PHONY: status
status:
	$(call header,$@)
	@kubectl exec -n vault -ti vault-0 -- vault status

.PHONY: logs
logs:
	$(call header,$@)
	@kubectl logs -n vault sts/vault -f

.PHONY: events
events:
	$(call header,$@)
	@kubectl get events --all-namespaces --sort-by='.metadata.creationTimestamp' -w

.PHONY: svc-health
svc-health:
	$(call header,$@)
	@curl -s http://localhost:8200/v1/sys/health | jq

.PHONY: health
health:
	$(call header,$@)
	@kubectl exec -n vault -ti vault-0 -- wget -qO - http://localhost:8200/v1/sys/health

.PHONY: vars
vars:
	@echo "export VAULT_ADDR=http://127.0.0.1:8200"
	@echo "export VAULT_TOKEN=root"

.PHONY: vso-install
vso-install:
	$(call header,$@)
	@helm install vault-secrets-operator hashicorp/vault-secrets-operator -n vault-secrets-operator-system --create-namespace --values vault-ent/vault-operator-values.yaml --version 0.8.1
	@sleep 10
	@kubectl wait --for=jsonpath='{.status.phase}'=Running pod --all --namespace vault-secrets-operator-system --timeout=1m
	@kubectl get all -n vault-secrets-operator-system
	@sleep 10

.PHONY: vso-upgrade
vso-uninstall:
	$(call header,$@)
	@helm uninstall vault-secrets-operator -n vault-secrets-operator-system

.PHONY: vso-uninstall
vso-logs:
	$(call header,$@)
	@kubectl logs -n vault-secrets-operator-system -l app.kubernetes.io/name=vault-secrets-operator -f

.PHONY: static-secrets
static-secrets:
	$(call header,$@)
	@kubectl cp -n vault ./vault-ent/static-secrets.sh vault-0:/tmp/static-secrets.sh
	@kubectl exec -n vault -ti vault-0 -- /bin/sh -c '/tmp/static-secrets.sh'
	@kubectl create ns app
	@kubectl apply -f vault-ent/vault-auth-static.yaml
	@kubectl apply -f vault-ent/static-secret.yaml
	@sleep 3
	@kubectl get secrets -n app -o yaml

.PHONY: dynamic-secrets
dynamic-secrets:
	$(call header,$@)
	@kubectl create ns postgres
	@helm upgrade --install postgres bitnami/postgresql --namespace postgres \
		--set auth.audit.logConnections=true  --set auth.postgresPassword=secret-pass
	@sleep 10
	@kubectl wait --for=jsonpath='{.status.phase}'=Running pod --all --namespace postgres --timeout=1m
	@kubectl cp -n vault ./vault-ent/dynamic-secrets/dynamic-secrets.sh vault-0:/tmp/dynamic-secrets.sh
	@kubectl exec -n vault -ti vault-0 -- /bin/sh -c '/tmp/dynamic-secrets.sh'
	@kubectl create ns demo-ns
	@kubectl apply -f vault-ent/dynamic-secrets/.
	@sleep 10
	@kubectl get secrets -n demo-ns -o yaml


.PHONY: pg-test
pg-test:
	$(call header,$@)
	@DB_USER=$(eval DB_USER=`kubectl get secret -n demo-ns vso-db-demo-created -o jsonpath='{.data.username}' | base64 -d`)
	@DB_PASS=$(eval DB_PASS=`kubectl get secret -n demo-ns vso-db-demo-created -o jsonpath='{.data.password}' | base64 -d`)
	@echo DB_USER: $(DB_USER)
	@echo DB_PASS: $(DB_PASS)
	@kubectl -ti -n postgres exec postgres-postgresql-0 -- /bin/sh -c "PGPASSWORD=\"$(DB_PASS)\" psql -U $(DB_USER) -d postgres -c 'SELECT datname FROM pg_database;'"