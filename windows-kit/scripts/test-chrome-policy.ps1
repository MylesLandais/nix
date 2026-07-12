#Requires -Version 5.1

[CmdletBinding()]
param(
    [string] $ConfigurationPath,
    [switch] $RequireAppliedPolicy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ConfigurationPath) {
    $ConfigurationPath = Join-Path $PSScriptRoot '..\config\chrome-policy.psd1'
}

$expectedExtensionId = 'hehggadaopoacecdllhhajmbjkdcmajg'
$config = Import-PowerShellDataFile -Path (Resolve-Path $ConfigurationPath)
$chatGpt = $config.Extensions.ChatGPT

if ($chatGpt.Id -ne $expectedExtensionId) {
    throw "Unexpected ChatGPT extension ID: $($chatGpt.Id)"
}
if ($chatGpt.InstallationMode -ne 'force_installed') {
    throw 'ChatGPT must be force_installed.'
}
if ($config.Browser.DeveloperToolsAvailability -ne 0) {
    throw 'DeveloperToolsAvailability must remain 0.'
}

Write-Host 'Chrome policy declaration: OK'

if (-not $RequireAppliedPolicy) { return }

$chromePaths = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)
if (-not ($chromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1)) {
    throw 'Google Chrome is not installed.'
}

$chromePolicyRoot = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
$forceListPath = Join-Path $chromePolicyRoot 'ExtensionInstallForcelist'
if (-not (Test-Path $forceListPath)) {
    throw 'Chrome ExtensionInstallForcelist policy does not exist.'
}

$extensionFound = (Get-ItemProperty -Path $forceListPath).PSObject.Properties |
    Where-Object { $_.Name -match '^\d+$' -and $_.Value -like "$expectedExtensionId;*" }
if (-not $extensionFound) {
    throw 'The ChatGPT extension is absent from ExtensionInstallForcelist.'
}

$extensionSettings = (Get-ItemPropertyValue -Path $chromePolicyRoot -Name ExtensionSettings) |
    ConvertFrom-Json
if ($extensionSettings.$expectedExtensionId.installation_mode -ne 'force_installed') {
    throw 'The ChatGPT ExtensionSettings entry is absent or incorrect.'
}

Write-Host 'Chrome installation: OK'
Write-Host 'ChatGPT extension machine policy: OK'
Write-Host 'Reload chrome://policy, then verify chrome://extensions.'
