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
    echo '${WslUser}:$WslPassword' | chpasswd
    usermod -aG sudo '$WslUser'
    # Allow passwordless sudo so the build script runs unattended.
    echo '$WslUser ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$WslUser
    chmod 440 /etc/sudoers.d/$WslUser
fi
"@
# Write the provisioning script to a temp file as UTF-8 *without a BOM* and run
# it via bash. Piping on stdin under Windows PowerShell 5.1 prepends a BOM that
# bash then chokes on ("set: command not found"), so avoid the pipe entirely.
$initFile = Join-Path ([System.IO.Path]::GetTempPath()) "wsl-init-$PID.sh"
# .NET UTF8Encoding($false) => no BOM; also normalize CRLF -> LF for bash.
[System.IO.File]::WriteAllText($initFile, ($initScript -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))
try {
    # Convert '\' to '/' before wslpath: backslashes get stripped when passed as
    # a wsl.exe argument, so a native Windows path fails to translate.
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

Write-Host "Entering $Distro as '$WslUser' (starting in the source directory)"
# Translate the Windows source dir to a WSL path, then open an interactive
# login shell there so the user can run the build-and-test steps by hand.
$wslScriptDir = (wsl.exe -d $Distro wslpath -a ($ScriptDir -replace '\\', '/')).Trim()
wsl.exe -d $Distro --cd "$wslScriptDir" -u $WslUser -- bash -l
