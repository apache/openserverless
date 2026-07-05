#Requires -Version 5.1
# Build-and-test driver for Windows via WSL.
# - installs WSL if missing
# - creates and starts an Ubuntu distribution
# - runs the first-boot setup so the user is prompted for username/password
# - runs build-and-test-linux.sh inside the distribution

$ErrorActionPreference = "Stop"

$Distro = "Ubuntu"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LinuxScript = "build-and-test-ubuntu.sh"

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

Write-Host "Starting $Distro and running first-boot setup (you will be asked for a username and password)"
# Launching the distro interactively triggers the Ubuntu first-run account creation
# (new UNIX username + password) when no user exists yet.
wsl.exe -d $Distro

Write-Host "Running $LinuxScript inside $Distro"
# Translate the Windows script path to a WSL path, then run it with bash.
$wslScriptPath = (wsl.exe -d $Distro wslpath -a "$ScriptDir\$LinuxScript").Trim()
wsl.exe -d $Distro bash -- $wslScriptPath

if ($LASTEXITCODE -ne 0) {
    Write-Error "build-and-test-linux.sh failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

Write-Host "Done."
