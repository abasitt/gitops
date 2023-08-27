#!/bin/bash

# Set the cleanup flag to true or false
cleanup=false

# Connect to the Vault instance
kubectl exec --stdin=true --tty=true vault-0 -n security -- /bin/sh

# Enable an instance of the Database Secrets Engine
vault secrets enable -path=demo-db database

# Configure the Database Secrets Engine, replacing the <<POSTGRES_PASSWORD>> with the password from above
vault write demo-db/config/demo-db \
  plugin_name=postgresql-database-plugin \
  allowed_roles="dev-postgres" \
  connection_url="postgresql://{{username}}:{{password}}@postgresql.demo-apps.svc.cluster.local:5432/postgres?sslmode=disable" \
  username="postgres" \
  password="dFs0fNFJdl"

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

# Check if the cleanup flag is true
if [ "$cleanup" = true ]; then
  # Delete the secrets engine
  vault secrets disable demo-db

  # Delete the role
  vault delete demo-db/roles/dev-postgres

  # Delete the policy
  vault policy delete demo-auth-policy-db
fi
