#!/bin/bash

# Connect to the Vault pod named vault-0 in the namespace vault
kubectl exec --stdin=true --tty=true vault-0 -n security -- /bin/sh

# Enable the Kubernetes auth method at demo-auth-mount path
vault auth enable -path demo-auth-mount kubernetes

# Configure the Kubernetes auth method with kubernetes_host
vault write auth/demo-auth-mount/config kubernetes_host="https://$KUBERNETES_PORT_443_TCP_ADDR:443"

# Enable the kv-v2 secrets engine at kvv2 path
vault secrets enable -path=kvv2 kv-v2

# Create a read only policy named dev
vault policy write dev - <<EOF
path "kvv2/*" {
   capabilities = ["read"]
}
EOF

# Create a role named role1 in the Kubernetes auth method
vault write auth/demo-auth-mount/role/role1 \
   bound_service_account_names=default \
   bound_service_account_namespaces=demo-app \
   policies=dev \
   audience=vault \
   ttl=24h

# Create a secret named webapp/config in the kv-v2 secrets engine
vault kv put kvv2/webapp/config username="static-user" password="static-password"

# Exit the Vault pod
exit
