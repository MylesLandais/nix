<#
  quick_fix.ps1 — post-install support payload (Windows 11 gaming profile).

  Run from the support USB after first boot:
      Right-click > Run with PowerShell   (it self-elevates)
    or
      powershell -NoProfile -ExecutionPolicy Bypass -File D:\quick_fix.ps1

  Does, idempotently and offline-first:
    * Silent installs of anything present under .\Installers\
        (Chrome, Steam, VLC, 7-Zip — missing ones are skipped, not fatal)
    * Force-installs uBlock Origin via Chrome enterprise policy
    * Restores the classic (Win10-style) right-click context menu so 7-Zip / VLC
      entries appear without "Show more options"
    * Removes common AppX bloat (Bing, Skype, GetHelp, Zune, Maps, Feedback, ...)

  Deliberately does NOT touch memory timings, overclocks, Secure Boot or TPM.
#>

# --- 1. elevate ---------------------------------------------------------------
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Re-launching with Administrator rights..."
    Start-Process PowerShell -Verb RunAs `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$ErrorActionPreference = 'Continue'
$UsbRoot       = Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallerPath = Join-Path $UsbRoot 'Installers'
$LogPath       = Join-Path $env:TEMP ("quick_fix_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
Start-Transcript -Path $LogPath -Force | Out-Null
Write-Host "Support payload starting. USB root: $UsbRoot" -ForegroundColor Cyan

# --- 2. silent offline installs ----------------------------------------------
# name -> { file, args }. Missing files are skipped (offline-first, not fatal).
$Apps = @(
    @{ Name = 'Google Chrome'; File = 'ChromeStandaloneSetup64.exe'; Args = '/silent /install' },
    @{ Name = '7-Zip';         File = '7z-x64.exe';                  Args = '/S' },
    @{ Name = 'VLC';           File = 'vlc-setup.exe';               Args = '/L=1033 /S' },
    @{ Name = 'Steam';         File = 'SteamSetup.exe';              Args = '/S' }
)
foreach ($app in $Apps) {
    $exe = Join-Path $InstallerPath $app.File
    if (Test-Path $exe) {
        Write-Host "Installing $($app.Name)..." -ForegroundColor Yellow
        Start-Process -FilePath $exe -ArgumentList $app.Args -Wait -NoNewWindow
        Write-Host "  $($app.Name) done."
    } else {
        Write-Host "Skipping $($app.Name) (not found: $($app.File))" -ForegroundColor DarkGray
    }
}

# --- 3. uBlock Origin via Chrome enterprise policy ---------------------------
# Force-install on first Chrome launch — far more reliable than sideloading .crx.
Write-Host "Configuring Chrome force-install (uBlock Origin)..." -ForegroundColor Yellow
$ChromeForce = 'HKLM:\SOFTWARE\Policies\Google\Chrome\ExtensionInstallForcelist'
if (-not (Test-Path $ChromeForce)) { New-Item -Path $ChromeForce -Force | Out-Null }
New-ItemProperty -Path $ChromeForce -Name '1' -PropertyType String -Force `
    -Value 'cjpalhdlnbpafiamejdnhcphjbkeiagm;https://clients2.google.com/service/update2/crx' | Out-Null

# --- 4. classic context menu (7-Zip / VLC visible on right-click) ------------
Write-Host "Restoring classic Win11 context menu..." -ForegroundColor Yellow
$ClsidKey = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
if (-not (Test-Path $ClsidKey)) { New-Item -Path $ClsidKey -Force | Out-Null }
# Empty (Default) value is the documented toggle.
Set-ItemProperty -Path $ClsidKey -Name '(Default)' -Value '' -Force

# --- 5. de-bloat (provisioned AppX) ------------------------------------------
Write-Host "Removing AppX bloat..." -ForegroundColor Yellow
$Bloat = @(
    '*BingNews*','*BingWeather*','*Microsoft3DViewer*','*MicrosoftOfficeHub*',
    '*SkypeApp*','*GetHelp*','*Getstarted*','*ZuneVideo*','*ZuneMusic*',
    '*WindowsMaps*','*FeedbackHub*','*MixedReality*','*Microsoft.549981C3F5F10*', # Cortana
    '*Clipchamp*','*Todos*','*PowerAutomate*'
)
foreach ($pkg in $Bloat) {
    Get-AppxPackage -Name $pkg -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue |
        Where-Object DisplayName -like $pkg |
        Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Out-Null
}

# --- 6. remote stack (virtio-win, RustDesk, Sunshine) -------------------------
foreach ($hook in @('install_virtio_win.ps1', 'install_rustdesk.ps1', 'install_sunshine.ps1')) {
    $hookPath = Join-Path $UsbRoot $hook
    if (Test-Path $hookPath) {
        Write-Host "Running $hook ..." -ForegroundColor Yellow
        & $hookPath
    }
}

# --- 7. apply ----------------------------------------------------------------
Write-Host "Restarting Explorer to apply context-menu change..." -ForegroundColor Yellow
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

Write-Host "Done. Log: $LogPath" -ForegroundColor Green
Write-Host "Reminder: chipset/GPU drivers live in .\Drivers\ — install AMD chipset then Adrenalin." -ForegroundColor Cyan
Stop-Transcript | Out-Null
