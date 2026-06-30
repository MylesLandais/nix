<#
  gamer_verify.ps1 — post-install gamer profile validation + quick_fix runner.

  Run from the payload CD after first boot to a local Owner session:
      powershell -NoProfile -ExecutionPolicy Bypass -File E:\gamer_verify.ps1

  Writes C:\gamer-profile-result.txt and runs quick_fix.ps1 from the same media root.
#>
$ErrorActionPreference = 'Continue'
$ResultPath = 'C:\gamer-profile-result.txt'
$MediaRoot  = Split-Path -Parent $MyInvocation.MyCommand.Path
$lines = @()

try {
    $lines += "WindowsProductName: $((Get-ComputerInfo).WindowsProductName)"
    $tpm = Get-Tpm
    $lines += "TpmPresent: $($tpm.TpmPresent)"
    $lines += "TpmReady: $($tpm.TpmReady)"
    $lines += "SecureBootUEFI: $(Confirm-SecureBootUEFI)"
} catch {
    $lines += "VerificationError: $_"
}

$lines | Set-Content -Path $ResultPath -Encoding UTF8
Write-Host ($lines -join "`n") -ForegroundColor Cyan

$quickFix = Join-Path $MediaRoot 'quick_fix.ps1'
if (Test-Path $quickFix) {
    & $quickFix
} else {
    Write-Warning "quick_fix.ps1 not found beside gamer_verify.ps1"
}
