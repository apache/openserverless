#!/bin/bash
set -euo pipefail

echo "Checking this is Linux Ubuntu"
if [[ "$(uname -s)" != "Linux" ]]; then
    echo "ERROR: this script must run on Linux, found $(uname -s)" >&2
    exit 1
fi
if ! grep -qi ubuntu /etc/os-release 2>/dev/null; then
    echo "ERROR: this script must run on Ubuntu" >&2
    exit 1
fi

echo "Killing k3s processes if present"
if [[ -x /usr/local/bin/k3s-killall.sh ]]; then
    sudo /usr/local/bin/k3s-killall.sh
fi

echo "Uninstalling k3s if present"
if [[ -x /usr/local/bin/k3s-uninstall.sh ]]; then
    sudo /usr/local/bin/k3s-uninstall.sh
fi
if [[ -x /usr/local/bin/k3s-agent-uninstall.sh ]]; then
    sudo /usr/local/bin/k3s-agent-uninstall.sh
fi

sudo apt-get update
sudo apt-get -y install jq unzip zip
sudo snap install go --classic
sudo snap install task --classic
sudo snap install kubectl --classic
curl -sL get.docker.com | sudo bash
sudo usermod -aG docker $USER
newgrp docker

task build
task test