#!/bin/bash

# shellcheck disable=SC2155
export PROJECT_DIR=$(git rev-parse --show-toplevel)

# shellcheck disable=SC2155
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt

# Prompt user for SOPS encryption input
read -rp "Perform SOPS encryption? (y/n): " sops_input
if [[ "$sops_input" == "y" ]]; then
    echo "Encrypting secrets with SOPS..."
    sops --encrypt --in-place "${PROJECT_DIR}/scripts/bootstrap/argocd/vars/cluster-secrets.sops.yaml"
    sops --encrypt --in-place "${PROJECT_DIR}/kubernetes/prod-cluster/apps/infra/cert-manager/issuer/secret.sops.yaml"
    # Uncomment and add more sops encryption commands if needed
else
    echo "Skipping SOPS encryption."
fi

# Install Helm 3
# Check if Helm is installed
if ! command -v helm &> /dev/null
then
    # Install Helm 3
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3
    chmod 700 get_helm.sh
    ./get_helm.sh
else
    # Helm is already installed, do nothing
    echo "Helm is already installed."
fi

# Prompt user for Cilium CNI installation input
read -rp "Install Cilium CNI? (y/n): " cni_input
if [[ "$cni_input" == "y" ]]; then
    echo "Installing Cilium CNI via Helm..."
    helm repo add cilium https://helm.cilium.io/
    helm repo update
    helm install cilium cilium/cilium --version 1.13.4 \
        --namespace kube-system \
        --set ipam.mode=kubernetes \
        --set cluster.name="home-k3s" \
        --set cluster.id=1 \
        --set bpf.masquerade=true \
        --set containerRuntime.integration=containerd \
        --set containerRuntime.socketPath=/var/run/k3s/containerd/containerd.sock \
        --set hubble.enabled=false \
        --set k8sServiceHost="192.168.40.18" \
        --set k8sServicePort=6443 \
        --set kubeProxyReplacement=strict \
        --set operator.replicas=1

    # Validate the installation
    cilium status --wait
else
    echo "Skipping CNI installation."
fi

# Prompt user for ArgoCD bootstrap input
read -rp "Bootstrap ArgoCD? (y/n): " argocd_input
if [[ "$argocd_input" == "y" ]]; then
    echo "Bootstraping ArgoCD bootstrap..."
    #create a namespace
    kubectl apply -f "${PROJECT_DIR}/scripts/bootstrap/argocd/ns.yaml"
    #install argocd
    kubectl kustomize "${PROJECT_DIR}/kubernetes/prod-cluster/infra/argocd/argocd" | kubectl apply -f -
    #check the status of all pods in argocd ns
    # Wait for all pods in the namespace to be ready
    kubectl wait --for=condition=ready --all pod -n argocd
    
    # Check the exit code of the previous command
    if [ $? -eq 0 ]; then
      # If the exit code is 0, it means all pods are ready
      echo "All pods in argocd are ready, applying argocd-self managed manifest ..."
      kubectl apply -f "${PROJECT_DIR}/scripts/bootstrap/argocd/app.yaml"
    else
      # If the exit code is not 0, it means some pods are not ready
      echo "Some pods in argocd are not ready, exiting argocd-self managed"
      # Exit the script with an error code
      exit 1
    fi
    # unecrypt and apply secret in a cluster
    sops --decrypt "${PROJECT_DIR}/scripts/bootstrap/argocd/vars/cluster-secrets.sops.yaml" | kubectl apply -f - 
else
    echo "Skipping ArgoCD bootstrap."
fi
