Set-StrictMode -Version Latest

function Ensure-RegistryKey {
    [CmdletBinding(SupportsShouldProcess)]
    param([Parameter(Mandatory)] [string] $Path)

    if (-not (Test-Path $Path) -and $PSCmdlet.ShouldProcess($Path, 'Create registry key')) {
        New-Item -Path $Path -Force | Out-Null
    }
}

function Set-RegistryPolicyValue {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [AllowNull()] [object] $Value
    )

    Ensure-RegistryKey -Path $Path
    $type = if ($Value -is [bool] -or $Value -is [int]) { 'DWord' }
        elseif ($Value -is [string]) { 'String' }
        else { throw "Unsupported registry value type for policy '$Name'." }
    if ($Value -is [bool]) { $Value = [int]$Value }

    if ($PSCmdlet.ShouldProcess("$Path\\$Name", "Set $type policy value")) {
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $type -Force | Out-Null
    }
}
