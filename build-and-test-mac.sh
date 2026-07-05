#!/bin/bash

set -euo pipefail

VM_NAME="openserverless"
# Mount and build in the CURRENT directory (where the script is launched from),
# not where the script file lives.
SRC_DIR="$(pwd)"
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
    --cpus=4 --memory=8 \
    --set ".mounts += [{\"location\": \"$SRC_DIR\", \"writable\": true}]"

# Path of the mounted source dir as seen inside the VM (lima mirrors the host path).
GUEST_SRC="$SRC_DIR"

echo "Provisioning the build user (docker + passwordless sudo)"
# The user that owns the mounted source already exists inside the VM (lima maps
# the host user in), so reuse it rather than creating one with a clashing uid.
# Give it docker + passwordless sudo so the build script needs no newgrp/usermod.
# The resolved username is written to a file we read back on the host.
BUILD_USER="$(limactl shell "$VM_NAME" sudo env GUEST_SRC="$GUEST_SRC" bash -euo pipefail <<'PROVISION'
# uid that owns the source files on the mount -> the user we build as.
SRC_UID="$(stat -c %u "$GUEST_SRC")"
BUILD_USER="$(getent passwd "$SRC_UID" | cut -d: -f1)"
if [ -z "$BUILD_USER" ]; then
    echo "no user owns $GUEST_SRC (uid $SRC_UID)" >&2
    exit 1
fi

# Install docker and add the build user to the docker + sudo groups.
which docker >/dev/null 2>&1 || curl -sL get.docker.com | sh >&2
usermod -aG docker,sudo "$BUILD_USER"

# Passwordless sudo.
echo "$BUILD_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/build-user
chmod 440 /etc/sudoers.d/build-user

echo "$BUILD_USER"
PROVISION
)"
echo "Build user is '$BUILD_USER'"

echo "Running $LINUX_SCRIPT inside the VM as '$BUILD_USER'"
# Run as the build user WITHOUT -i: a login shell would reset the working dir to
# the user's home. -H sets $HOME; the script cd's into the source dir itself.
limactl shell --workdir "$GUEST_SRC" "$VM_NAME" sudo -H -u "$BUILD_USER" bash -- "$GUEST_SRC/$LINUX_SCRIPT"
