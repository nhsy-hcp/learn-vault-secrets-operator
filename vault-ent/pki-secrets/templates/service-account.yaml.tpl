apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: ${APP_NAME}
  name: ${APP_NAME}-sa
  annotations:
    # Copied into the Vault entity alias metadata at login (use_annotations_as_alias_metadata)
    vault.hashicorp.com/alias-metadata-pki_role: ${APP_NAME}
    vault.hashicorp.com/alias-metadata-application_name: ${APP_NAME}
    vault.hashicorp.com/alias-metadata-namespace: ${APP_NAME}
    vault.hashicorp.com/alias-metadata-team: platform
    vault.hashicorp.com/alias-metadata-business_unit: shared-services
