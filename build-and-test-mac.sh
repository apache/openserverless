#!/bin/bash

set -euo pipefail

VM_NAME="openserverless"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LINUX_SCRIPT="build-and-test-ubuntu.sh"

echo "Checking this is a Mac"
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "ERROR: this script must run on macOS (Darwin), found $(uname -s)" >&2
    exit 1
fi

echo "Checking lima is installed"
if ! command -v limactl >/dev/null 2>&1; then
    echo "ERROR: lima (limactl) is not installed. Install it with 'brew install lima'" >&2
    exit 1
fi

echo "Destroying existing '$VM_NAME' VM if it exists"
if limactl list --quiet 2>/dev/null | grep -qx "$VM_NAME"; then
    limactl stop -f "$VM_NAME" 2>/dev/null || true
    limactl delete -f "$VM_NAME"
fi

echo "Creating '$VM_NAME' VM with the source dir mounted writable"
# Mount the source directory writable so `go build` can write the ops binary
# back into the tree (the default lima mounts are read-only).
limactl start --name="$VM_NAME" --tty=false \
    --set ".mounts += [{\"location\": \"$SCRIPT_DIR\", \"writable\": true}]"

echo "Running $LINUX_SCRIPT inside the VM"
limactl shell "$VM_NAME" bash -- "$SCRIPT_DIR/$LINUX_SCRIPT"
