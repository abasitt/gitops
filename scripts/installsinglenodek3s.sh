#!/bin/bash

echo "Please choose an option:"
echo "1. Install k3s"
echo "2. Uninstall k3s"
read -rp "Enter your choice (1 or 2): " choice

if [[ $choice == "1" ]]; then
    echo "Starting k3s installation..."
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='--flannel-backend=none --disable-network-policy --disable=traefik --disable servicelb' sh -
    #k3s config in bashrc
    if ! grep -q "export KUBECONFIG=/etc/rancher/k3s/k3s.yaml" ~/.bashrc; then
      echo '# Add kubeconfig for k3s' >> ~/.bashrc
      echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml' >> ~/.bashrc
    fi
    source ~/.bashrc
    echo "k3s installed successfully!"
elif [[ $choice == "2" ]]; then
    echo "Starting k3s uninstallation..."
    
    ip link delete cilium_host
    ip link delete cilium_net
    ip link delete cilium_vxlan

    iptables-save | grep -iv cilium | iptables-restore
    ip6tables-save | grep -iv cilium | ip6tables-restore

    /usr/local/bin/k3s-uninstall.sh
    echo "k3s uninstalled successfully!"
else
    echo "Invalid choice. Exiting..."
    exit 1
fi
