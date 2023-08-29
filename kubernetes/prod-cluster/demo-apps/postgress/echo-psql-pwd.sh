#!/bin/bash


POSTGRES_PASSWORD=$(kubectl get secret --namespace demo-apps postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)
echo "$POSTGRES_PASSWORD"

# read the demo secret
#k get secrets -n demo-apps vso-db-demo -oyaml -o jsonpath="{.data.password}" | base64 -d