Set-StrictMode -Version Latest

$script:ChromePolicyRoot = 'HKLM:\SOFTWARE\Policies\Google\Chrome'
$script:ChromeExtensionForceList = Join-Path $script:ChromePolicyRoot 'ExtensionInstallForcelist'

function Get-ChromeExecutable {
    [CmdletBinding()]
    param()

    @(
        "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
        "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}

function ConvertTo-ChromeExtensionSettings {
    [CmdletBinding()]
    param([Parameter(Mandatory)] [hashtable] $Extensions)

    $settings = @{}
    foreach ($extension in $Extensions.Values) {
        $settings[$extension.Id] = @{
            installation_mode = $extension.InstallationMode
            update_url = $extension.UpdateUrl
        }
    }
    $settings | ConvertTo-Json -Depth 10 -Compress
}
