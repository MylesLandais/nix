#Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param([switch] $RemoveAllChromePolicies)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
$forceList = Join-Path $root 'ExtensionInstallForcelist'

if ($RemoveAllChromePolicies) {
    if ((Test-Path $root) -and $PSCmdlet.ShouldProcess($root, 'Remove all locally managed Chrome policies')) {
        Remove-Item -Path $root -Recurse -Force
    }
    return
}

if ((Test-Path $forceList) -and $PSCmdlet.ShouldProcess($forceList, 'Remove managed extension list')) {
    Remove-Item -Path $forceList -Recurse -Force
}
if ((Test-Path $root) -and $PSCmdlet.ShouldProcess($root, 'Remove ExtensionSettings')) {
    Remove-ItemProperty -Path $root -Name ExtensionSettings -ErrorAction SilentlyContinue
}
