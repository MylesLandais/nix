<#
  Configures a Windows remote-development workstation from repository state.
  Run from an elevated PowerShell. RustDesk is intentionally out of scope.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string] $ChromePolicyConfiguration = (Join-Path $PSScriptRoot 'config\chrome-policy.psd1'),
    [switch] $SkipChromePolicy
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'WinDevConfig\WinDevConfig.psm1') -Force

if (-not (Test-WinDevAdministrator)) {
    throw 'Run this script from an elevated PowerShell session.'
}

Install-WinGetPackage -Id 'Google.Chrome'
Install-WinGetPackage -Id 'Tailscale.Tailscale'
# Microsoft Store product ID used by OpenAI's managed Windows deployment.
Install-WinGetPackage -Id '9NT1R1C2HH7J' -Source msstore
Install-WinGetPackage -Id 'OpenJS.NodeJS.LTS'

# WinGet/MSI updates persistent PATH, not the already-running PowerShell process.
$env:Path = @(
    [Environment]::GetEnvironmentVariable('Path', 'Machine')
    [Environment]::GetEnvironmentVariable('Path', 'User')
) -join ';'

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    throw 'Node.js was installed, but npm is still unavailable after refreshing PATH.'
}

# npm exposes PowerShell shims (*.ps1). Windows clients default to Restricted,
# which makes an installed `codex` fail while codex.cmd works. Allow local
# scripts for this user without weakening machine or Group Policy scopes.
if ((Get-ExecutionPolicy) -eq 'Restricted') {
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
}

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    Invoke-WinDevNative npm @('install', '--global', '@openai/codex')
}

if (-not $SkipChromePolicy) {
    & (Join-Path $PSScriptRoot 'scripts\apply-chrome-policy.ps1') `
        -ConfigurationPath $ChromePolicyConfiguration
}

if (-not (Test-TailnetConnection)) {
    Write-Warning 'Tailscale is installed but this host is not connected to a tailnet.'
    Write-Host 'Authenticate now with: tailscale up'
} else {
    Write-Host 'Tailscale tailnet connection verified.' -ForegroundColor Green
}

Write-Host ''
Write-Host 'Remote-development software and policy are configured.' -ForegroundColor Green
Write-Host 'Manual account-bound steps:'
Write-Host '  1. Sign in to ChatGPT Desktop.'
Write-Host '  2. Authenticate Codex with: codex login'
Write-Host '  3. Confirm the ChatGPT extension reports Connected and approve sites'
Write-Host '     interactively in ChatGPT Computer Use settings.'
Write-Host '  4. Verify machine policy at chrome://policy and restart Chrome if requested.'
