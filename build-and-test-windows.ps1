#Requires -Version 5.1
# Build-and-test driver for Windows via WSL.
# - installs WSL if missing
# - creates and starts an Ubuntu distribution
# - initializes it non-interactively: removes k3s, creates a sudo user, sets it default
# - Enter in the distro

$ErrorActionPreference = "Stop"

$Distro = "Ubuntu"
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
    Write-Host "WSL not found. Installing WSL with the $Distro distribution..."
    wsl.exe --install -d $Distro
    Write-Warning "WSL was just installed. A reboot is usually required to finish setup."
    Write-Warning "Please reboot Windows and re-run this script."
    exit 0
}

Write-Host "Ensuring the $Distro distribution exists"
$installed = (wsl.exe --list --quiet) -replace "`0", "" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
if ($installed -notcontains $Distro) {
    Write-Host "Installing $Distro distribution..."
    wsl.exe --install -d $Distro --no-launch
}

Write-Host "Initializing $Distro as root (removing k3s, docker, creating user '$WslUser')"
# On WSL there is no host user mapped in, so we create the build user ourselves.
# We do it by running provisioning commands directly as root (wsl -u root), no
# boot command. The script is idempotent: removes k3s, ensures docker, and
# creates '$WslUser' with docker + passwordless sudo.
$initScript = @"
set -e

# Remove k3s if it is installed inside the distribution.
if [ -x /usr/local/bin/k3s-killall.sh ]; then /usr/local/bin/k3s-killall.sh; fi
if [ -x /usr/local/bin/k3s-uninstall.sh ]; then /usr/local/bin/k3s-uninstall.sh; fi
if [ -x /usr/local/bin/k3s-agent-uninstall.sh ]; then /usr/local/bin/k3s-agent-uninstall.sh; fi

# Ensure docker is installed.
command -v docker >/dev/null 2>&1 || curl -sL get.docker.com | sh

# Create the build user if it does not already exist (idempotent).
if ! id -u '$WslUser' >/dev/null 2>&1; then
    useradd -m -s /bin/bash '$WslUser'
    echo '${WslUser}:$WslPassword' | chpasswd
fi

# Add it to the docker + sudo groups and grant passwordless sudo.
usermod -aG docker,sudo '$WslUser'
echo '$WslUser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$WslUser
chmod 440 /etc/sudoers.d/$WslUser

# Make sure the docker daemon is running.
service docker start >/dev/null 2>&1 || true
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

Write-Host "Setting '$WslUser' as the default user for $Distro"
# Use wsl.exe --manage: the per-distro launcher (e.g. Ubuntu.exe) is not always on
# PATH and its name does not reliably match the distro name.
wsl.exe --manage $Distro --set-default-user $WslUser
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to set default user for $Distro"
    exit $LASTEXITCODE
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
