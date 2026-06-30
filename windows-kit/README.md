# windows-kit

Text templates for the Windows deployment & support kit. The **scripts** that use
these live in `../scripts/`; the **runbook** is `../docs/cluster/windows-deploy.md`.

Binaries (Windows ISO, drivers, BIOS `.CAP`, MAS) are **never committed** — they
stage off-repo (default `~/win-kit-staging/`, gitignored) and get copied onto the
USBs at build time.

## Contents

| File | Role |
|------|------|
| `autounattend.xml` | 24H2 answer file: local account, skip MS-account/OOBE, **keep TPM 2.0 + Secure Boot** (anti-cheat). Edition selector only — does **not** activate. |
| `quick_fix.ps1` | Post-install payload: apps, de-bloat, context menu, uBlock; hooks remote-stack installers. |
| `gamer_verify.ps1` | QEMU check: `C:\gamer-profile-result.txt` (Pro/TPM/SB), then `quick_fix.ps1`. |
| `install_rustdesk.ps1` | Silent RustDesk + firewall; password via `WIN_RUSTDESK_PASSWORD`. |
| `install_sunshine.ps1` | Sunshine for Moonlight; PIN via `WIN_SUNSHINE_PIN`. |
| `install_virtio_win.ps1` | virtio-win from staged ISO (required before SPICE virtio-vga). |
| `driver-manifest.md` | Driver matrix for B850-E / 9850X3D / RX 9070 XT. |

## Staging layout (`~/win-kit-staging/`)

```
Windows.iso
virtio-win.iso              # Fedora virtio-win (for QEMU SPICE + virtio bus)
Installers/
  ChromeStandaloneSetup64.exe  SteamSetup.exe  vlc-setup.exe  7z-x64.exe
  rustdesk-1.4.6-x86_64.exe    # optional offline RustDesk
  Sunshine-Setup.exe           # optional offline Sunshine
Drivers/
  chipset/  gpu/  net/  audio/
firmware/
  <ASUS BIOS>.zip
golden/                     # sealed qcow2 + ovmf-vars.fd + swtpm/ + manifest.json
quick_fix.ps1               # copy from windows-kit/ (or use --payload-dir)
```

## Quick start

```bash
# Install + payload
nix run .#test-windows-qemu -- --iso ~/win-kit-staging/Windows.iso --fresh \
  --payload-dir ~/win-kit-staging --target /tmp/win11-pro-gamer.qcow2

# Boot installed disk with SPICE viewer + remote port forwards
nix run .#test-windows-qemu -- --boot-target \
  --target /tmp/win11-pro-gamer.qcow2 \
  --payload-dir ~/win-kit-staging --open-spice --user-net

# Boot sealed golden (after seal-windows-golden)
nix run .#boot-windows-golden

# Host RustDesk → guest
nix run .#rustdesk-windows-qemu
```

Guest login: `Owner` / `ChangeMe!2026` (change in `autounattend.xml` before hardware).

Edit `autounattend.xml` before building: review `DiskConfiguration` (**wipes Disk 0**).

Activation is intentionally left out (install unactivated).
