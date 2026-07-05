#Requires -Version 5.1
# Build-and-test driver for Windows via WSL.
# - installs WSL if missing
# - creates and starts an Ubuntu distribution
# - initializes it non-interactively: removes k3s, creates a sudo user, sets it default
# - runs build-and-test-ubuntu.sh inside the distribution

$ErrorActionPreference = "Stop"

$Distro = "Ubuntu"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LinuxScript = "build-and-test-ubuntu.sh"

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

Write-Host "Initializing $Distro (removing k3s, creating sudo user '$WslUser')"
# Fresh Ubuntu WSL distros boot as root until a default user is set, so run the
# provisioning as root. This is done non-interactively (no first-boot prompt).
$initScript = @"
set -e

# Remove k3s if it is installed inside the distribution.
if [ -x /usr/local/bin/k3s-killall.sh ]; then /usr/local/bin/k3s-killall.sh; fi
if [ -x /usr/local/bin/k3s-uninstall.sh ]; then /usr/local/bin/k3s-uninstall.sh; fi
if [ -x /usr/local/bin/k3s-agent-uninstall.sh ]; then /usr/local/bin/k3s-agent-uninstall.sh; fi

# Create the sudo-enabled user if it does not already exist.
if ! id -u '$WslUser' >/dev/null 2>&1; then
    useradd -m -s /bin/bash '$WslUser'
    echo '$WslUser:$WslPassword' | chpasswd
    usermod -aG sudo '$WslUser'
    # Allow passwordless sudo so the build script runs unattended.
    echo '$WslUser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$WslUser
    chmod 440 /etc/sudoers.d/$WslUser
fi
"@
# Pass the script on stdin to avoid Windows/WSL quoting issues.
$initScript | wsl.exe -d $Distro -u root bash
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to initialize $Distro"
    exit $LASTEXITCODE
}

Write-Host "Setting '$WslUser' as the default user for $Distro"
# The `<distro> config --default-user` launcher command persists the default user.
& "$Distro.exe" config --default-user $WslUser

Write-Host "Running $LinuxScript inside $Distro"
# Translate the Windows script path to a WSL path, then run it with bash.
$wslScriptPath = (wsl.exe -d $Distro wslpath -a "$ScriptDir\$LinuxScript").Trim()
wsl.exe -d $Distro bash -- $wslScriptPath

if ($LASTEXITCODE -ne 0) {
    Write-Error "build-and-test-linux.sh failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "Done."
