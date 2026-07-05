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
which docker || curl -sL get.docker.com | sudo bash
sudo usermod -aG docker $USER

newgrp docker <<EOF

# Install go, task and kubectl WITHOUT snap: snapd mounts each snap via snapfuse
# under WSL, which silently presents an empty mountpoint (meta/snap.yaml missing),
# so `task`/`go`/`kubectl` fail. Direct binaries avoid the whole snap machinery.

# Map uname -m to the Go/k8s arch naming used by the download URLs.
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64) GOARCH=amd64 ;;
    aarch64) GOARCH=arm64 ;;
    *) echo "ERROR: unsupported architecture $ARCH" >&2; exit 1 ;;
esac

echo "Installing Go"
GO_VERSION=1.26.4
curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${GOARCH}.tar.gz" -o /tmp/go.tar.gz
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf /tmp/go.tar.gz
rm -f /tmp/go.tar.gz
# Make go available on PATH for this session and for future login shells.
export PATH="/usr/local/go/bin:$PATH"
echo 'export PATH=/usr/local/go/bin:$PATH' | sudo tee /etc/profile.d/go.sh >/dev/null

echo "Installing Task"
# Official installer drops the 'task' binary into the given -b directory.
curl -fsSL https://taskfile.dev/install.sh | sudo sh -s -- -d -b /usr/local/bin

echo "Installing kubectl"
KUBECTL_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/${GOARCH}/kubectl" -o /tmp/kubectl
sudo install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
rm -f /tmp/kubectl

curl -sL get.docker.com | sed -e 's/sleep 20/sleep 1/'  | sudo bash
sudo usermod -aG docker $USER

newgrp docker <<EOF
git config --global --add safe.directory $PWD/olaris-op
export PATH=/usr/local/go/bin:/usr/local/bin:\$PATH
task build
task test
EOF