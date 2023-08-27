#!/bin/bash

# Connect to the Vault pod named vault-0 in the namespace vault
kubectl -n security exec --stdin=true --tty=true vault-0 -n vault -- /bin/sh

# Delete the secret named webapp/config in the kv-v2 secrets engine
vault kv delete kvv2/webapp/config

# Delete the role named role1 in the Kubernetes auth method
vault delete auth/demo-auth-mount/role/role1

# Delete the policy named dev
vault policy delete dev

# Disable the kv-v2 secrets engine at kvv2 path
vault secrets disable kvv2

# Disable the Kubernetes auth method at demo-auth-mount path
vault auth disable demo-auth-mount

# Exit the Vault pod
exit
