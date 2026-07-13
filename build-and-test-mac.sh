#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.


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

echo "Resolving the build user from the mount owner"
# The user that owns the mounted source already exists inside the VM (lima maps
# the host user in), so reuse it rather than creating one with a clashing uid.
# Resolve it in its OWN command so nothing else can pollute the captured stdout:
# the provisioning step below installs docker, whose installer prints to stdout,
# and folding that into the same capture is what made BUILD_USER come back as
# multi-line garbage (resolving to root) on first run.
SRC_UID="$(limactl shell "$VM_NAME" stat -c %u "$GUEST_SRC")"
BUILD_USER="$(limactl shell "$VM_NAME" getent passwd "$SRC_UID" | cut -d: -f1)"
if [ -z "$BUILD_USER" ] || [ "$BUILD_USER" = "root" ]; then
    echo "ERROR: could not resolve a non-root build user owning $GUEST_SRC (uid ${SRC_UID:-?})" >&2
    exit 1
fi
echo "Build user is '$BUILD_USER'"

echo "Provisioning the build user (docker + passwordless sudo)"
# Give it docker + passwordless sudo so the build script needs no newgrp/usermod.
# All output goes to stderr; this block returns nothing on stdout.
limactl shell "$VM_NAME" sudo env BUILD_USER="$BUILD_USER" bash -euo pipefail >&2 <<'PROVISION'
# Install docker and add the build user to the docker + sudo groups.
which docker >/dev/null 2>&1 || curl -sL get.docker.com | sh
usermod -aG docker,sudo "$BUILD_USER"

# Passwordless sudo.
echo "$BUILD_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/build-user
chmod 440 /etc/sudoers.d/build-user
PROVISION

# usermod -aG only affects NEW logins, but lima multiplexes every `limactl shell`
# over one persistent SSH master connection whose session predates the group add.
# Drop that master socket so the next `limactl shell` logs in fresh and actually
# has the docker group; otherwise `docker` calls hit a permission-denied socket.
rm -f ~/.lima/"$VM_NAME"/ssh.sock

echo "Running $LINUX_SCRIPT inside the VM as '$BUILD_USER'"
# Run as the build user WITHOUT -i: a login shell would reset the working dir to
# the user's home. -H sets $HOME; the script cd's into the source dir itself.

limactl shell --workdir "$GUEST_SRC" "$VM_NAME" sudo -H -u "$BUILD_USER" bash -- "$GUEST_SRC/$LINUX_SCRIPT"
