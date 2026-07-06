#!/bin/bash
set -euo pipefail

# This script builds and tests the sources. It expects to run as a user that
# already has passwordless sudo and is a member of the docker group (the host
# driver — build-and-test-mac.sh / build-and-test-windows.ps1 — sets that up).
# It must run from the source directory, which the user can write to.

echo "Checking this is Linux Ubuntu"
if [[ "$(uname -s)" != "Linux" ]]; then
    echo "ERROR: this script must run on Linux, found $(uname -s)" >&2
    exit 1
fi
if ! grep -qi ubuntu /etc/os-release 2>/dev/null; then
    echo "ERROR: this script must run on Ubuntu" >&2
    exit 1
fi

echo "Checking Docker is accessible"
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker is not installed" >&2
    exit 1
fi
if ! docker ps >/dev/null 2>&1; then
    echo "ERROR: cannot access the Docker daemon (permission denied or daemon not running)." >&2
    echo "       Ensure the daemon is running and this user is in the 'docker' group." >&2
    echo "       If you were just added to the group, start a fresh session (e.g. 'newgrp docker')." >&2
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

# Install go, task and kubectl WITHOUT snap: snapd mounts each snap via snapfuse
# under WSL, which silently presents an empty mountpoint (meta/snap.yaml missing),
# so `task`/`go`/`kubectl` fail. Direct binaries avoid the whole snap machinery.

# Map dpkg arch (amd64/arm64) to the Go/k8s arch naming used by the download URLs.
GOARCH="$(dpkg --print-architecture)"

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

export PATH="/usr/local/go/bin:/usr/local/bin:$PATH"

echo "Building and testing"
# cd into the source dir (where this script lives) so `task` finds the Taskfile,
# regardless of the caller's working directory (e.g. a login shell resets it).
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
git config --global --add safe.directory "$PWD"
git config --global --add safe.directory "$PWD/olaris-op"
task build
task test
