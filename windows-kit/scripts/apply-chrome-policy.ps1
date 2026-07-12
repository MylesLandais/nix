#Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess)]
param([string] $ConfigurationPath)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ConfigurationPath) {
    $ConfigurationPath = Join-Path $PSScriptRoot '..\config\chrome-policy.psd1'
}
. (Join-Path $PSScriptRoot '..\modules\registry.ps1')
. (Join-Path $PSScriptRoot '..\modules\chrome.ps1')
$config = Import-PowerShellDataFile -Path (Resolve-Path $ConfigurationPath)

if ($PSCmdlet.ShouldProcess($script:ChromePolicyRoot, 'Apply managed Chrome policy')) {
    Ensure-RegistryKey -Path $script:ChromePolicyRoot
    Ensure-RegistryKey -Path $script:ChromeExtensionForceList

    (Get-ItemProperty -Path $script:ChromeExtensionForceList).PSObject.Properties |
        Where-Object { $_.Name -match '^\d+$' } |
        ForEach-Object {
            Remove-ItemProperty -Path $script:ChromeExtensionForceList -Name $_.Name -Force
        }

    $index = 1
    foreach ($extension in $config.Extensions.Values) {
        if ($extension.Id -notmatch '^[a-p]{32}$') {
            throw "Invalid Chrome extension ID: $($extension.Id)"
        }
        Set-RegistryPolicyValue -Path $script:ChromeExtensionForceList `
            -Name ([string]$index) -Value "$($extension.Id);$($extension.UpdateUrl)"
        $index++
    }

    Set-RegistryPolicyValue -Path $script:ChromePolicyRoot -Name ExtensionSettings `
        -Value (ConvertTo-ChromeExtensionSettings -Extensions $config.Extensions)
    foreach ($policy in $config.Browser.GetEnumerator()) {
        Set-RegistryPolicyValue -Path $script:ChromePolicyRoot `
            -Name $policy.Key -Value $policy.Value
    }
}

Write-Host 'Chrome machine policies applied. Restart Chrome and reload chrome://policy.'
