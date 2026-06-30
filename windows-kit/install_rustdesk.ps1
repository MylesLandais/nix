<#
  install_rustdesk.ps1 — silent RustDesk install for QEMU + physical targets.

  Offline-first: stage Installers\rustdesk-<ver>-x86_64.exe (or rustdesk-x86_64.exe).
  Env: WIN_RUSTDESK_PASSWORD (default ChangeMe!RD2026)
#>
$ErrorActionPreference = 'Stop'
$Version  = '1.4.6'
$Password = if ($env:WIN_RUSTDESK_PASSWORD) { $env:WIN_RUSTDESK_PASSWORD } else { 'ChangeMe!RD2026' }
$Marker   = 'C:\ProgramData\win-kit\rustdesk.installed'
$Root     = Split-Path -Parent $MyInvocation.MyCommand.Path
$Installers = Join-Path $Root 'Installers'

if (Test-Path $Marker) {
    Write-Host "RustDesk already installed ($Marker)" -ForegroundColor DarkGray
    return
}

$exe = @(
    (Join-Path $Installers "rustdesk-$Version-x86_64.exe"),
    (Join-Path $Installers 'rustdesk-x86_64.exe'),
    (Join-Path $Installers 'rustdesk.exe')
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $exe) {
    $dest = Join-Path $env:TEMP "rustdesk-$Version-x86_64.exe"
    $url  = "https://github.com/rustdesk/rustdesk/releases/download/$Version/rustdesk-$Version-x86_64.exe"
    Write-Host "Downloading RustDesk $Version..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
    $exe = $dest
}

Write-Host "Installing RustDesk from $exe ..." -ForegroundColor Yellow
Start-Process -FilePath $exe -ArgumentList '--silent-install' -Wait -NoNewWindow

$configDir = "${env:ProgramFiles}\RustDesk\config"
$config    = Join-Path $configDir 'RustDesk2.toml'
if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
@"
[options]
verification-method = "use-permanent-password"
access-model = "lock"
approve-mode = "password"
permanent-password = "$Password"
"@ | Set-Content -Path $config -Encoding UTF8

foreach ($proto in @('TCP', 'UDP')) {
    $existing = Get-NetFirewallRule -DisplayName "RustDesk-$proto" -ErrorAction SilentlyContinue
    if (-not $existing) {
        New-NetFirewallRule -DisplayName "RustDesk-$proto" -Direction Inbound `
            -Protocol $proto -LocalPort 21115-21119 -Action Allow | Out-Null
    }
}

Start-Service -Name 'RustDesk' -ErrorAction SilentlyContinue
Set-Service -Name 'RustDesk' -StartupType Automatic -ErrorAction SilentlyContinue

New-Item -ItemType Directory -Path (Split-Path $Marker) -Force | Out-Null
Set-Content -Path $Marker -Value (Get-Date -Format o)
Write-Host "RustDesk installed. Password: (see WIN_RUSTDESK_PASSWORD / kit default)" -ForegroundColor Green
