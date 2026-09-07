#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    throw 'winget is unavailable. Install or update Microsoft App Installer.'
}

$packageId = 'Google.Chrome'
$null = & winget list --id $packageId --exact --accept-source-agreements 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host 'Google Chrome is already installed.'
    return
}

& winget install --id $packageId --exact --source winget --silent `
    --accept-package-agreements --accept-source-agreements
if ($LASTEXITCODE -ne 0) {
    throw "Chrome installation failed with exit code $LASTEXITCODE."
}
