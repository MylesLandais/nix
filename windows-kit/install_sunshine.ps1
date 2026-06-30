<#
  install_sunshine.ps1 — Sunshine host for Moonlight streaming inside Windows guest.

  Offline-first: stage Installers\Sunshine-Setup.exe (pin release in kit docs).
  Env: WIN_SUNSHINE_PIN (default 1234)
#>
$ErrorActionPreference = 'Stop'
$Marker = 'C:\ProgramData\win-kit\sunshine.installed'
$Pin    = if ($env:WIN_SUNSHINE_PIN) { $env:WIN_SUNSHINE_PIN } else { '1234' }
$Root   = Split-Path -Parent $MyInvocation.MyCommand.Path
$Installers = Join-Path $Root 'Installers'

if (Test-Path $Marker) {
    Write-Host "Sunshine already installed ($Marker)" -ForegroundColor DarkGray
    return
}

$exe = @(
    (Join-Path $Installers 'Sunshine-Setup.exe'),
    (Join-Path $Installers 'sunshine-windows-installer.exe')
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $exe) {
    Write-Warning "Sunshine installer not in Installers\ — download from LizardByte releases and re-run"
    return
}

Write-Host "Installing Sunshine from $exe ..." -ForegroundColor Yellow
Start-Process -FilePath $exe -ArgumentList '/S' -Wait -NoNewWindow

$sunshineConf = "$env:ProgramFiles\Sunshine\config\sunshine.conf"
if (-not (Test-Path (Split-Path $sunshineConf))) {
    $sunshineConf = "$env:LOCALAPPDATA\Sunshine\sunshine.conf"
}
$confDir = Split-Path $sunshineConf
if (-not (Test-Path $confDir)) { New-Item -ItemType Directory -Path $confDir -Force | Out-Null }
if (-not (Test-Path $sunshineConf)) { New-Item -ItemType File -Path $sunshineConf -Force | Out-Null }
Add-Content -Path $sunshineConf -Value "pin = $Pin"

foreach ($proto in @('TCP', 'UDP')) {
    $existing = Get-NetFirewallRule -DisplayName "Sunshine-$proto" -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-NetFirewallRule -DisplayName "Sunshine-$proto" -Direction Inbound `
            -Protocol $proto -LocalPort 47984-47990 -Action Allow | Out-Null
    }
}

Start-Service -Name 'SunshineService' -ErrorAction SilentlyContinue
Set-Service -Name 'SunshineService' -StartupType Automatic -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Path (Split-Path $Marker) -Force | Out-Null
Set-Content -Path $Marker -Value (Get-Date -Format o)
Write-Host "Sunshine installed. Moonlight PIN: $Pin (override via WIN_SUNSHINE_PIN)" -ForegroundColor Green
