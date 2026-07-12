#Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$steps = @(
    'scripts\install-chrome.ps1'
    'scripts\apply-chrome-policy.ps1'
    'scripts\test-chrome-policy.ps1'
)
foreach ($relativePath in $steps) {
    $path = Join-Path $PSScriptRoot $relativePath
    Write-Host "`nRunning $relativePath"
    if ($relativePath -eq 'scripts\test-chrome-policy.ps1') {
        & $path -RequireAppliedPolicy
    } else {
        & $path
    }
}
