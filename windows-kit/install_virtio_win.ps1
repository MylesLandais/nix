<#
  install_virtio_win.ps1 — virtio-win guest drivers (required before SPICE virtio-vga).

  Offline: stage virtio-win.iso beside payload or at Installers\virtio-win.iso
  Env: VIRTIO_ISO_PATH — full path to mounted ISO or directory
#>
$ErrorActionPreference = 'Continue'
$Marker = 'C:\ProgramData\win-kit\virtio-win.installed'
if (Test-Path $Marker) {
    Write-Host "virtio-win already installed ($Marker)" -ForegroundColor DarkGray
    return
}

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$isoCandidates = @(
    $env:VIRTIO_ISO_PATH,
    (Join-Path $Root 'virtio-win.iso'),
    (Join-Path $Root 'Installers\virtio-win.iso'),
    'D:\virtio-win.iso',
    'E:\virtio-win.iso'
) | Where-Object { $_ -and (Test-Path $_) }

$iso = $isoCandidates | Select-Object -First 1
if (-not $iso) {
    Write-Warning "virtio-win.iso not found — skip driver install (SPICE virtio-vga unavailable)"
    return
}

$mount = $null
try {
    if ((Get-Item $iso).PSIsContainer) {
        $driverRoot = $iso
    } else {
        $mount = Mount-DiskImage -ImagePath $iso -PassThru
        $vol = ($mount | Get-Volume).DriveLetter
        $driverRoot = "${vol}:\"
    }

    $guestOs = '2k22'  # Win11 uses Win10 driver tree
    $paths = @(
        (Join-Path $driverRoot "guestos\$guestOs"),
        (Join-Path $driverRoot 'vioserial'),
        (Join-Path $driverRoot 'viofs'),
        (Join-Path $driverRoot 'NetKVM'),
        (Join-Path $driverRoot 'Balloon'),
        (Join-Path $driverRoot 'qxldod')
    ) | Where-Object { Test-Path $_ }

    foreach ($p in $paths) {
        Write-Host "pnputil: $p" -ForegroundColor Yellow
        pnputil /add-driver (Join-Path $p '*.inf') /install 2>&1 | Out-Null
    }

    New-Item -ItemType Directory -Path (Split-Path $Marker) -Force | Out-Null
    Set-Content -Path $Marker -Value (Get-Date -Format o)
    Write-Host "virtio-win drivers staged — reboot may be required for virtio-vga" -ForegroundColor Green
} finally {
    if ($mount) { Dismount-DiskImage -ImagePath $iso -ErrorAction SilentlyContinue }
}
