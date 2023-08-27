#!/bin/bash

# Set the name of the vault pod
VAULT_POD=vault-0

# Set the number of unseal keys required
UNSEAL_KEYS=3

# Loop through the unseal keys and run the unseal command
for i in $(seq 1 $UNSEAL_KEYS)
do
  # Prompt the user to enter the unseal key
  echo "Enter unseal key $i:"
  read -s UNSEAL_KEY

  # Run the vault operator unseal command on the pod
  kubectl exec $VAULT_POD -n security -- vault operator unseal $UNSEAL_KEY
done

# Check the vault status
kubectl exec $VAULT_POD -n security -- vault status
