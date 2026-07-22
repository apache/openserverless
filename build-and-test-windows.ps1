#Requires -Version 5.1

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

# Build-and-test driver for Windows via WSL.
# - installs WSL if missing
# - creates and starts a dedicated Ubuntu distribution
# - initializes it non-interactively: removes k3s, creates a sudo user, sets it default
# - Enter in the distro and run tesst/build-and-test-ubuntu.sh as the ops user
#
# WARNING: this script DESTROYS AND REBUILDS the WSL distribution named by
# $Distro on every run (`wsl --unregister`, which is irreversible). It therefore
# uses a dedicated name of its own rather than a common one like 'Ubuntu', and
# refuses to delete any distribution it did not create without confirmation.

[CmdletBinding()]
param(
    # Skip the confirmation prompt before destroying an existing distribution.
    # Intended for CI. Interactive users should leave this off.
    [switch]$Force
)

$ErrorActionPreference = "Stop"

# The distribution this script owns. It is DESTROYED AND REBUILT on every run,
# so it deliberately does NOT default to a name a developer is likely to be
# using themselves ('Ubuntu', 'Ubuntu-24.04', ...). Override with WSL_DISTRO.
$Distro = if ($env:WSL_DISTRO) { $env:WSL_DISTRO } else { "openserverless-build" }

# The image the distribution is created from. WSL can install the same image
# under any name (`wsl --install -d <image> --name <distro>`), which is what
# keeps $Distro independent of whatever the user already has installed.
$Image = if ($env:WSL_IMAGE) { $env:WSL_IMAGE } else { "Ubuntu-24.04" }

# Marker file written inside the distribution during provisioning. Its presence
# is what lets a later run know the distro is this script's to destroy.
$OwnedMarker = "/etc/openserverless-build-distro"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Default UNIX account created inside the distribution (override with env vars).
$WslUser = if ($env:WSL_USER) { $env:WSL_USER } else { "ops" }
$WslPassword = if ($env:WSL_PASSWORD) { $env:WSL_PASSWORD } else { "ops" }

function Test-WslInstalled {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        return $false
    }
    # `wsl --status` returns a non-zero exit code when WSL is not usable.
    wsl.exe --status *> $null
    return ($LASTEXITCODE -eq 0)
}

Write-Host "Checking WSL is installed"
if (-not (Test-WslInstalled)) {
    Write-Host "WSL not found. Installing WSL..."
    wsl.exe --install --no-distribution
    Write-Warning "WSL was just installed. A reboot is usually required to finish setup."
    Write-Warning "Please reboot Windows and re-run this script."
    exit 0
}

Write-Host "Checking for an existing $Distro distribution"
$installed = (wsl.exe --list --quiet) -replace "`0", "" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
if ($installed -contains $Distro) {
    # `wsl --unregister` deletes the distribution's virtual disk. It is
    # IRREVERSIBLE - there is no recycle bin and no undo. Never do it to a
    # distribution this script did not create without asking first.
    $marker = (wsl.exe -d $Distro -u root -- sh -c "test -f $OwnedMarker && echo owned" 2>$null)
    $isOwned = ($LASTEXITCODE -eq 0) -and (($marker -replace "`0", "").Trim() -eq "owned")

    if (-not ($isOwned -or $Force)) {
        Write-Host ""
        Write-Warning "A WSL distribution named '$Distro' already exists, but it was not created by this script."
        Write-Warning "Continuing DESTROYS it permanently, including every file inside it."
        Write-Host ""
        Write-Host "  If this is a distribution you use, answer 'no' and set a different name instead:"
        Write-Host "      `$env:WSL_DISTRO = 'openserverless-build-2'; .\build-and-test-windows.ps1"
        Write-Host ""
        Write-Host "  Existing distributions on this machine:"
        $installed | ForEach-Object { Write-Host "      $_" }
        Write-Host ""

        $answer = Read-Host "Permanently delete the '$Distro' distribution and rebuild it? Type 'yes' to confirm"
        if ($answer -ne "yes") {
            Write-Host "Aborted. Nothing was changed."
            exit 1
        }
    }

    Write-Host "Unregistering existing $Distro distribution..."
    wsl.exe --unregister $Distro
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to unregister $Distro"
        exit $LASTEXITCODE
    }
}

Write-Host "Installing a fresh $Distro distribution from the $Image image"
wsl.exe --install -d $Image --name $Distro --no-launch
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to install $Distro from the $Image image"
    exit $LASTEXITCODE
}

Write-Host "Initializing $Distro as root (removing k3s, docker, creating user '$WslUser')"
# On WSL there is no host user mapped in, so we create the build user ourselves.
# We do it by running provisioning commands directly as root (wsl -u root), no
# boot command. The script is idempotent: removes k3s, ensures docker, and
# creates '$WslUser' with docker + passwordless sudo.
$initScript = @"
set -e
set -o pipefail

export DEBIAN_FRONTEND=noninteractive

# Mark this distribution as created by (and therefore safe to be destroyed by)
# this script. Later runs check for this file before unregistering.
echo 'Created by build-and-test-windows.ps1. This distribution is rebuilt from scratch on every run.' > $OwnedMarker

# Drop the Windows PATH entries WSL injects. The [interop] setting written to
# /etc/wsl.conf below only takes effect after the restart, and this distro is
# recreated from scratch on every run - so provisioning itself would still see
# Docker Desktop's docker.exe and misbehave (get.docker.com warns about an
# "existing" docker and sleeps 40s). Strip them here so init is deterministic.
PATH="`$(printf '%s' "`$PATH" | tr ':' '\n' | grep -v '^/mnt/' | paste -sd: -)"
export PATH

# Remove k3s if it is installed inside the distribution.
if [ -x /usr/local/bin/k3s-killall.sh ]; then /usr/local/bin/k3s-killall.sh; fi
if [ -x /usr/local/bin/k3s-uninstall.sh ]; then /usr/local/bin/k3s-uninstall.sh; fi
if [ -x /usr/local/bin/k3s-agent-uninstall.sh ]; then /usr/local/bin/k3s-agent-uninstall.sh; fi

# Ensure docker is installed INSIDE the distribution. WSL appends the Windows
# PATH, so a plain `command -v docker` also matches Docker Desktop's
# /mnt/c/.../docker.exe - which makes the install look done while the distro has
# no daemon at all. Only a binary outside /mnt counts.
has_linux_docker() {
    case "`$(command -v docker 2>/dev/null)" in
        ''|/mnt/*) return 1 ;;
        *) return 0 ;;
    esac
}

# Download the installer to a file first: piping curl into sh hides a failed
# download, since sh happily runs an empty script.
if ! has_linux_docker; then
    apt-get update
    apt-get install -y ca-certificates curl
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
fi
has_linux_docker || { echo "docker installation failed: no native docker binary in the distribution" >&2; exit 1; }

# get.docker.com creates the 'docker' group, but create it defensively so the
# usermod below cannot fail on a partial install.
getent group docker >/dev/null || groupadd docker

# Create the build user if it does not already exist (idempotent).
if ! id -u '$WslUser' >/dev/null 2>&1; then
    useradd -m -s /bin/bash '$WslUser'
    echo '${WslUser}:$WslPassword' | chpasswd
fi

# Add it to the docker + sudo groups and grant passwordless sudo.
usermod -aG docker,sudo '$WslUser'
echo '$WslUser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$WslUser
chmod 440 /etc/sudoers.d/$WslUser

# Ensure ~/.ssh exists: the devcontainer bind-mounts \${HOME}/.ssh and docker
# refuses to start if the source path is missing.
sudo -u '$WslUser' mkdir -p /home/$WslUser/.ssh
sudo -u '$WslUser' chmod 700 /home/$WslUser/.ssh

# Make sure the docker daemon starts now AND on every subsequent boot: this
# distro is restarted (wsl --shutdown) right after provisioning, so a one-shot
# start would be lost.
if [ -d /run/systemd/system ]; then
    systemctl enable --now docker
else
    service docker start
fi

# Write a known-good /etc/wsl.conf. This distro is always created fresh by this
# script, so we own the file outright rather than patching it in place.
# Requires a `wsl --shutdown` to take effect (done below).
#
#   systemd           - needed so the docker service can be enabled/started.
#   automount metadata- honor Unix permissions (incl. the executable bit) on
#                       /mnt/c; without it scripts on the mount cannot be run
#                       directly (fork/exec fails, "no such file or directory").
#   appendWindowsPath - keep this distro ISOLATED from the Windows toolchain.
#                       Otherwise Docker Desktop's docker.exe leaks onto PATH
#                       and shadows/masquerades as a working docker install,
#                       even though this distro has no Desktop integration.
mkdir -p /etc
cat > /etc/wsl.conf <<'EOF'
[boot]
systemd=true

[automount]
options = "metadata"

[interop]
enabled = true
appendWindowsPath = false
EOF
"@

# Write the script to a BOM-less, LF-normalized temp file (PS 5.1 stdin pipes
# prepend a BOM that bash chokes on), then run it as root inside the distro.
$initFile = Join-Path ([System.IO.Path]::GetTempPath()) "wsl-init-$PID.sh"
[System.IO.File]::WriteAllText($initFile, ($initScript -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
try {
    $wslInitPath = (wsl.exe -d $Distro wslpath -a ($initFile -replace '\\', '/')).Trim()
    wsl.exe -d $Distro -u root -- bash "$wslInitPath"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to initialize $Distro"
        exit $LASTEXITCODE
    }
} finally {
    Remove-Item -LiteralPath $initFile -ErrorAction SilentlyContinue
}

# Restart WSL so the /etc/wsl.conf 'metadata' automount option is applied.
# Until the distro is remounted, /mnt/c ignores the executable bit and scripts
# on it cannot be run directly.
Write-Host "Restarting WSL to apply mount options"
wsl.exe --shutdown

Write-Host "Setting '$WslUser' as the default user for $Distro"
# Use wsl.exe --manage: the per-distro launcher (e.g. Ubuntu.exe) is not always on
# PATH and its name does not reliably match the distro name.
wsl.exe --manage $Distro --set-default-user $WslUser
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set default user for $Distro"
    exit $LASTEXITCODE
}

Write-Host "Waiting for the Docker daemon in $Distro"
# After the restart the distro boots cold; give dockerd a chance to come up so
# the build script does not fail on a race. Use a temp script file rather than
# `bash -c '...'`: wsl.exe re-parses the command line and mangles inline quoting.
$waitScript = @'
systemctl start docker >/dev/null 2>&1 || true
for i in $(seq 1 30); do
    docker info >/dev/null 2>&1 && exit 0
    sleep 2
done
systemctl --no-pager status docker || true
exit 1
'@
$waitFile = Join-Path ([System.IO.Path]::GetTempPath()) "wsl-wait-$PID.sh"
[System.IO.File]::WriteAllText($waitFile, ($waitScript -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
try {
    $wslWaitPath = (wsl.exe -d $Distro wslpath -a ($waitFile -replace '\\', '/')).Trim()
    wsl.exe -d $Distro -u root -- bash "$wslWaitPath"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker daemon did not become ready in $Distro"
        exit $LASTEXITCODE
    }
} finally {
    Remove-Item -LiteralPath $waitFile -ErrorAction SilentlyContinue
}

Write-Host "Running build-and-test-ubuntu.sh in $Distro as '$WslUser'"
# Run the build/test script as ops from the source directory. ops was created
# with the mount's owning uid/gid, so it can write the build output in place;
# it has docker + passwordless sudo, so no newgrp/usermod is needed in-script.
$wslScriptDir = (wsl.exe -d $Distro wslpath -a ($ScriptDir -replace '\\', '/')).Trim()
wsl.exe -d $Distro --cd "$wslScriptDir" -u $WslUser -- bash -lc "./build-and-test-ubuntu.sh"
if ($LASTEXITCODE -ne 0) {
    Write-Error "build-and-test-ubuntu.sh failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "Done."
