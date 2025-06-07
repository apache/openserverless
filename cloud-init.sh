#!/bin/bash
IP="$(ip -4 -o addr | awk  '$2 ~ /en/ {print $4}' | cut -d/ -f1)"

#  setup k3s
if ! which k3s
then curl -sfL https://get.k3s.io | sudo sh -
fi

# kubeconfig with local ip

if ! test -f "$HOME/.kube/config"
then
    mkdir -p "$HOME/.kube"
    sudo cat  /etc/rancher/k3s/k3s.yaml |\
    sed -e 's!server: https://127.0.0.1:6443!server: https://'$IP':6443!' \
    >"$HOME/.kube/config"
    echo "export KUBECONFIG=$HOME/.kube/config" >> "$HOME/.bashrc"
fi

kubectl get nodes


echo "=== DONE ===" 
