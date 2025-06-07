#!/bin/bash
#  setup k3s
curl -sfL https://get.k3s.io | sudo sh -
mkdir -p "$HOME/.kube"
sudo cat  /etc/rancher/k3s/k3s.yaml >"$HOME/.kube/config"

# setup ops
curl -sL bit.ly/get-ops | bash
source ~/.bashrc
ops -t
IP="$(ip -4 -o addr | awk  '$2 ~ /en/ {print $4}' | cut -d/ -f1)"
APIHOST="http://$IP.nip.io"

echo "-------"
echo "APIHOST=$APIHOST"
