#!/bin/bash

# create a namespace
kubectl apply -f ns.yaml

#install argocd
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.7.6/manifests/install.yaml

# unecrypt and apply secret in a cluster
sops --decrypt {{.KUBERNETES_DIR}}/flux/vars/cluster-secrets.sops.yaml | kubectl apply -f -

# Apply the kustomization to the cluster
kubectl apply sops secret

