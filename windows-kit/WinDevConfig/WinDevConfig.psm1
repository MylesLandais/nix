Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-WinDevAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-WinDevNative {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $FilePath,
        [Parameter()] [string[]] $ArgumentList = @()
    )

    & $FilePath @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath failed with exit code $LASTEXITCODE"
    }
}

function Install-WinGetPackage {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string] $Id,
        [Parameter()] [ValidateSet('winget', 'msstore')] [string] $Source = 'winget'
    )

    $installed = & winget list --id $Id --exact --accept-source-agreements 2>$null
    if ($LASTEXITCODE -eq 0 -and ($installed -join "`n") -match [regex]::Escape($Id)) {
        Write-Verbose "$Id is already installed."
        return
    }

    if ($PSCmdlet.ShouldProcess($Id, 'Install with winget')) {
        Invoke-WinDevNative winget @(
            'install', '--id', $Id, '--exact', '--source', $Source,
            '--accept-package-agreements', '--accept-source-agreements', '--silent'
        )
    }
}

function Test-TailnetConnection {
    [CmdletBinding()]
    param()

    $tailscale = Get-Command tailscale -ErrorAction SilentlyContinue
    if (-not $tailscale) { return $false }
    $null = & tailscale status --json 2>$null
    return $LASTEXITCODE -eq 0
}

Export-ModuleMember -Function @(
    'Install-WinGetPackage',
    'Invoke-WinDevNative',
    'Test-TailnetConnection',
    'Test-WinDevAdministrator'
)
