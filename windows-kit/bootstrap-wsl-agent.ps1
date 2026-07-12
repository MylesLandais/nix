<#
  bootstrap-wsl-agent.ps1 — Windows-side setup for the NixOS-WSL agent
  workstation (host modules/hosts/7PZSZY2).

  Idempotent: safe to re-run. Each stage checks a marker or existing state
  before doing anything. Run from an elevated (Administrator) PowerShell.

  Env overrides:
    WSL_AGENT_NIXOS_RELEASE   (default 2605.7.2)
    WSL_AGENT_DISTRO_NAME     (default NixOS)
    WSL_AGENT_INSTALL_DIR     (default C:\WSL\NixOS)
#>
$ErrorActionPreference = 'Stop'

$Release    = if ($env:WSL_AGENT_NIXOS_RELEASE) { $env:WSL_AGENT_NIXOS_RELEASE } else { '2605.7.2' }
$DistroName = if ($env:WSL_AGENT_DISTRO_NAME)   { $env:WSL_AGENT_DISTRO_NAME }   else { 'NixOS' }
$InstallDir = if ($env:WSL_AGENT_INSTALL_DIR)   { $env:WSL_AGENT_INSTALL_DIR }   else { 'C:\WSL\NixOS' }
$MarkerRoot = 'C:\ProgramData\win-kit'
$Root       = Split-Path -Parent $MyInvocation.MyCommand.Path

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Invoke-Native {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Command
    )

    & $Command
    if ($LASTEXITCODE -ne 0) {
        throw "Native command failed with exit code ${LASTEXITCODE}: $Command"
    }
}

if (-not (Test-Admin)) {
    Write-Host 'Re-run this script from an elevated (Administrator) PowerShell.' -ForegroundColor Red
    exit 1
}

New-Item -ItemType Directory -Force -Path $MarkerRoot | Out-Null

# --- 1. WSL platform features + engine -------------------------------------
$wslMarker = Join-Path $MarkerRoot 'wsl-features.installed'
if (-not (Test-Path $wslMarker)) {
    Write-Host 'Enabling WSL + VirtualMachinePlatform...' -ForegroundColor Yellow
    Invoke-Native { wsl --install --no-distribution }
    Write-Host 'A restart may be required before continuing. Re-run this script after rebooting if `wsl --status` errors out.' -ForegroundColor Yellow
    Set-Content -Path $wslMarker -Value (Get-Date -Format o)
} else {
    Write-Host 'WSL platform features already enabled.' -ForegroundColor DarkGray
}

Write-Host 'Updating WSL engine...' -ForegroundColor Yellow
Invoke-Native { wsl --update }
Invoke-Native { wsl --version }

# --- 2. .wslconfig (mirrored networking) ------------------------------------
$wslConfigPath = Join-Path $env:UserProfile '.wslconfig'
$wslConfigBody = @"
[wsl2]
networkingMode=mirrored
dnsTunneling=true
firewall=true
autoProxy=true
localhostForwarding=true

[experimental]
hostAddressLoopback=true
autoMemoryReclaim=gradual
sparseVhd=true
"@

$needsWrite = $true
if (Test-Path $wslConfigPath) {
    $existing = Get-Content $wslConfigPath -Raw
    if ($existing.Trim() -eq $wslConfigBody.Trim()) { $needsWrite = $false }
}
if ($needsWrite) {
    Write-Host "Writing $wslConfigPath (mirrored networking)..." -ForegroundColor Yellow
    $wslConfigBackup = "$wslConfigPath.before-wsl-agent"
    if ((Test-Path $wslConfigPath) -and -not (Test-Path $wslConfigBackup)) {
        Copy-Item -Path $wslConfigPath -Destination $wslConfigBackup
        Write-Host "Preserved the previous configuration at $wslConfigBackup" -ForegroundColor DarkGray
    }
    Set-Content -Path $wslConfigPath -Value $wslConfigBody -Encoding UTF8
    Write-Host 'Restarting the WSL VM to apply networking changes...' -ForegroundColor Yellow
    Invoke-Native { wsl --shutdown }
} else {
    Write-Host '.wslconfig already up to date.' -ForegroundColor DarkGray
}

# --- 3. NixOS-WSL distro install --------------------------------------------
$installedDistrosRaw = @(wsl --list --quiet 2>$null)
if ($LASTEXITCODE -ne 0) {
    throw "Unable to list installed WSL distributions (exit code ${LASTEXITCODE})."
}
$installedDistros = @(
    $installedDistrosRaw |
        ForEach-Object { $_.Replace("`0", '').Trim() } |
        Where-Object { $_ }
)
$distroInstalled = $installedDistros -contains $DistroName
if (-not $distroInstalled) {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    $wslFile = Join-Path $Root "nixos-$Release.wsl"
    if (-not (Test-Path $wslFile)) {
        $url = "https://github.com/nix-community/NixOS-WSL/releases/download/$Release/nixos.wsl"
        Write-Host "Downloading NixOS-WSL $Release..." -ForegroundColor Yellow
        Invoke-WebRequest -Uri $url -OutFile $wslFile -UseBasicParsing
    }
    $checksumUrl = "https://github.com/nix-community/NixOS-WSL/releases/download/$Release/nixos.wsl.sha256"
    $expectedHash = ((Invoke-RestMethod -Uri $checksumUrl) -split '\s+')[0].ToUpperInvariant()
    $actualHash = (Get-FileHash -Path $wslFile -Algorithm SHA256).Hash
    if ($actualHash -ne $expectedHash) {
        Remove-Item -Path $wslFile -Force
        throw "Checksum verification failed for $wslFile"
    }
    Write-Host "Importing $DistroName from $wslFile..." -ForegroundColor Yellow
    Invoke-Native { wsl --install --from-file $wslFile --name $DistroName --location $InstallDir }
} else {
    Write-Host "$DistroName distro already installed." -ForegroundColor DarkGray
}

# --- 4. Chrome isolated debug profile ---------------------------------------
$chromeProfileDir = 'C:\ChromeProfiles\AgentDebug'
New-Item -ItemType Directory -Force -Path $chromeProfileDir | Out-Null

$chromeScriptDir = 'C:\Scripts'
New-Item -ItemType Directory -Force -Path $chromeScriptDir | Out-Null
$chromeScript = Join-Path $chromeScriptDir 'chrome-agent-debug.ps1'
$chromeScriptBody = @'
$ChromeCandidates = @(
  "${env:ProgramFiles}\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "${env:LocalAppData}\Google\Chrome\Application\chrome.exe"
)
$Chrome = $ChromeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $Chrome) { throw 'Google Chrome was not found.' }
$Profile = "C:\ChromeProfiles\AgentDebug"

& $Chrome `
  --remote-debugging-port=9222 `
  --remote-debugging-address=127.0.0.1 `
  --user-data-dir="$Profile" `
  --no-first-run `
  --no-default-browser-check
'@
Set-Content -Path $chromeScript -Value $chromeScriptBody -Encoding UTF8
Write-Host "Chrome debug launcher: $chromeScript" -ForegroundColor DarkGray
Write-Host '  (never point --remote-debugging-address at anything but 127.0.0.1' -ForegroundColor DarkGray
Write-Host '   unless a Windows Firewall rule restricts port 9222 to the WSL adapter.)' -ForegroundColor DarkGray

# --- 5. Tailscale check (does not install by default) -----------------------
$tailscale = Get-Command tailscale -ErrorAction SilentlyContinue
if (-not $tailscale) {
    Write-Host 'Tailscale not found on PATH.' -ForegroundColor Yellow
    Write-Host '  Install with: winget install tailscale.tailscale' -ForegroundColor Yellow
    Write-Host '  (left as a manual step — winget prompts are not silent-install friendly here)' -ForegroundColor DarkGray
} else {
    Write-Host 'Tailscale already installed.' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host 'Done. Next steps:' -ForegroundColor Green
Write-Host "  1. wsl -d $DistroName"
Write-Host '  2. passwd'
Write-Host '  3. mkdir -p ~/Workspace-git && cd ~/Workspace-git'
Write-Host '  4. git clone https://github.com/MylesLandais/nix.git && cd nix'
Write-Host '  5. sudo nixos-rebuild switch --flake path:$HOME/Workspace-git/nix#7PZSZY2'
Write-Host "  6. $chromeScript"
Write-Host '  7. From WSL: curl http://127.0.0.1:9222/json/version'
Write-Host '  8. .\setup-remote-development.ps1  # ChatGPT, Codex, Chrome policy, tailnet'
