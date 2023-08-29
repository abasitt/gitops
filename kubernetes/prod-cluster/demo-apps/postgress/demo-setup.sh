#!/bin/bash

# Set the cleanup flag to true or false
cleanup=false

# read the password
POSTGRES_PASSWORD=$(kubectl get secret --namespace demo-apps postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)

# Connect to the Vault instance
kubectl exec --stdin=true --tty=true vault-0 -n security -- env PASSWORD="$POSTGRES_PASSWORD" /bin/sh

# Enable an instance of the Database Secrets Engine
vault secrets enable -path=demo-db database

# Configure the Database Secrets Engine, replacing the <<POSTGRES_PASSWORD>> with the password from above
vault write demo-db/config/demo-db \
  plugin_name=postgresql-database-plugin \
  allowed_roles="dev-postgres" \
  connection_url="postgresql://{{username}}:{{password}}@postgresql.demo-apps.svc.cluster.local:5432/postgres?sslmode=disable" \
  username="postgres" \
  password="$PASSWORD"

# Create a role for the postgres pod
vault write demo-db/roles/dev-postgres \
  db_name=demo-db \
  creation_statements="CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}'; \
     GRANT ALL PRIVILEGES ON DATABASE postgres TO \"{{name}}\";" \
  backend=demo-db \
  name=dev-postgres \
  default_ttl="1m" \
  max_ttl="1m"

# Create the demo-auth-policy-db policy
vault policy write demo-auth-policy-db - <<EOF
path "demo-db/creds/dev-postgres" {
  capabilities = ["read"]
}
EOF

# ----

# Create a new role for the dynamic secret
vault write auth/demo-auth-mount/role/auth-role \
  bound_service_account_names=default \
  bound_service_account_namespaces=demo-apps \
  token_ttl=0 \
  token_max_ttl=120 \
  token_policies=demo-auth-policy-db \
  audience=vault

# Enable an instance of the Transit Secrets Engine at the path demo-transit
vault secrets enable -path=demo-transit transit

# Create a secret cache configuration
vault write demo-transit/cache-config size=500

# Create a encryption key
vault write -force demo-transit/keys/vso-client-cache

# Create a policy for the operator role to access the encryption key
vault policy write demo-auth-policy-operator - <<EOF
path "demo-transit/encrypt/vso-client-cache" {
  capabilities = ["create", "update"]
}
path "demo-transit/decrypt/vso-client-cache" {
  capabilities = ["create", "update"]
}
EOF

# Create Kubernetes auth role for the operator
vault write auth/demo-auth-mount/role/auth-role-operator \
  bound_service_account_names=demo-operator \
  bound_service_account_namespaces=demo-apps \
  token_ttl=0 \
  token_max_ttl=120 \
  token_policies=demo-auth-policy-db \
  audience=vault

# Check if the cleanup flag is true
if [ "$cleanup" = true ]; then
  # Delete the secrets engine
  vault secrets disable demo-db

  # Delete the role
  vault delete demo-db/roles/dev-postgres

  # Delete the policy
  vault policy delete demo-auth-policy-db

  # ---

  # Delete the role
  vault delete auth/demo-auth-mount/role/auth-role

  # Delete the secrets engine
  vault secrets disable demo-transit

  # Delete the key
  vault delete demo-transit/keys/vso-client-cache

  # Delete the policies
  vault policy delete demo-auth-policy-db
  vault policy delete demo-auth-policy-operator
fi
