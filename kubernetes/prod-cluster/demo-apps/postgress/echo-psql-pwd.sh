#!/bin/bash


export POSTGRES_PASSWORD=$(kubectl get secret --namespace demo-apps postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)
echo $POSTGRES_PASSWORD