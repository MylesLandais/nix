# Windows deploy runbook

Boot + install Windows on real hardware from a USB built on cerberus, validated
first in QEMU. Companion to the Kali runbook (`kali-lacie-boot.md`). The kit:
`scripts/write-windows-usb.sh`, `scripts/test-windows-qemu.sh`,
`scripts/build-firmware-usb.sh`, `scripts/fetch-driver-pack.sh`, and the templates
in `windows-kit/`.

## Why this exists

The lacie GRUB-loopback toolkit can *stage* a Windows ISO but **cannot boot it**
(`setup-nix-usb.sh` says so). Windows needs its own UEFI boot, and modern Win11
`install.wim` is >4 GiB so it won't fit raw FAT32. So we build a dedicated,
UEFI-clean installer USB: single FAT32 ESP, `install.wim` split into `.swm`
chunks with `wimlib` — no NTFS, no UEFI:NTFS shim (the layer that's been flaky on
our hardware).

## Anti-cheat constraint

Keep **TPM 2.0 + Secure Boot ENABLED** on the target — Vanguard/EAC/BattlEye
require them. The `autounattend.xml` only removes the Microsoft-account/OOBE
online wall; it does **not** bypass TPM/Secure Boot/RAM. The QEMU harness
validates *with* swtpm + Secure Boot on, so a clean VM install means the
anti-cheat prerequisites are genuinely met.

## 0. Stage payload (off-repo, gitignored)

Put the Win11 24H2 ISO + app installers + drivers under `~/win-kit-staging/`
(layout in `windows-kit/README.md`). Optionally:

```bash
./scripts/fetch-driver-pack.sh --winpe   # extract vendor .exe/.zip -> .inf trees
```

Edit `windows-kit/autounattend.xml`: change the `Owner` password, review the
`DiskConfiguration` (**it wipes Disk 0** — confirm the target is the only/right
disk on the machine).

## 1. Validate in QEMU first (no hardware)

ISO mode injects `autounattend.xml` via a **virtual floppy** (no physical USB
required). Default answer file: `windows-kit/autounattend.xml`.

```bash
# Dry-run — confirm OVMF.ms, swtpm, floppy, and qcow2 target in the plan
nix run .#test-windows-qemu -- --iso ~/win-kit-staging/Windows.iso \
  --fresh --dry-run

# Media check — does it reach Windows Setup? (no install disk, no floppy)
nix run .#test-windows-qemu -- --iso ~/win-kit-staging/Windows.iso --check-media

# Full unattended dry-run — floppy autounattend + scratch qcow2 install
nix run .#test-windows-qemu -- --iso ~/win-kit-staging/Windows.iso --fresh \
  --target /tmp/win11-pro-gamer.qcow2 --vnc :1

# Gamer profile — attach payload ISO (quick_fix.ps1 + Installers/) as second CD
nix run .#test-windows-qemu -- --iso ~/win-kit-staging/Windows.iso --fresh \
  --payload-dir ~/win-kit-staging --target /tmp/win11-pro-gamer.qcow2 --vnc :1
```

After first boot, run the validation script from the payload CD (letter varies —
use `Get-Volume` in PowerShell):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\gamer_verify.ps1
```

That writes `C:\gamer-profile-result.txt`, runs `quick_fix.ps1`, and logs to
`%TEMP%\quick_fix_*.log`. Or boot the installed disk without the install ISO:

```bash
nix run .#test-windows-qemu -- --boot-target \
  --target /tmp/win11-pro-gamer.qcow2 \
  --payload-dir ~/win-kit-staging --vnc :1
```

Guest checks (also printed by `gamer_verify.ps1`):

```powershell
(Get-ComputerInfo).WindowsProductName   # Windows 11 Pro
Get-Tpm                                 # TpmPresent True
Confirm-SecureBootUEFI                  # True
```

Pass if: reaches Setup → installs unattended → reboots into OOBE → lands on a
**local** account with **no** Microsoft sign-in prompt, all with Secure Boot +
TPM 2.0 on. (swtpm + OVMF_VARS.ms.fd come from the flake app's runtime closure.)

If setup stalls at "Select language", floppy autounattend was not picked up —
fall back to USB passthrough (`write-windows-usb.sh` + `--device /dev/sdX`).

### Console matrix (GTK / VNC / SPICE)

| Mode | Flags | Viewer | Notes |
|------|-------|--------|-------|
| GTK | default | QEMU window | Works on cerberus with local display |
| VNC | `--vnc :1` | manual → `localhost:5901` | Headless |
| VNC auto | `--vnc :1 --open-viewer` | `remote-viewer` / `vncviewer` | |
| SPICE | `--spice` | manual → `spice://127.0.0.1:5935` | Needs virtio-win in guest |
| SPICE auto | `--open-spice` | `remote-viewer` / `virt-viewer` | Preferred after virtio-win |

AHCI scratch images boot with GTK or VNC until `install_virtio_win.ps1` runs.
After virtio-win, use `--open-spice` for clipboard + resolution sync (vdagent).

### Port map (QEMU `--user-net`)

| Service | Ports | Host connect |
|---------|-------|--------------|
| SPICE | 5935 | `remote-viewer spice://127.0.0.1:5935` |
| VNC display `:1` | 5901 | `vnc://127.0.0.1:5901` |
| RustDesk | 21115–21119 TCP, 21116 UDP | `nix run .#rustdesk-windows-qemu` |
| Moonlight / Sunshine | 47984–47990 TCP+UDP | Moonlight → `127.0.0.1:47989` |

### Credentials

| Context | User | Password / secret |
|---------|------|-------------------|
| Local account (autounattend) | `Owner` | `ChangeMe!2026` — change before hardware |
| RustDesk guest | — | `WIN_RUSTDESK_PASSWORD` (default `ChangeMe!RD2026`) |
| Sunshine / Moonlight | — | `WIN_SUNSHINE_PIN` (default `1234`) |

### Golden image layout (`~/win-kit-staging/golden/`)

```
win11-pro-gamer-<tag>.qcow2   # compressed sealed disk
ovmf-vars.fd                  # persistent Secure Boot NVRAM
swtpm/                        # persistent TPM 2.0 state
manifest.json                 # sha256, autounattend hash, verified flag
```

Seal after verification:

```bash
nix run .#seal-windows-golden -- \
  --source /tmp/win11-pro-gamer.qcow2 \
  --ovmf-vars /path/to/last-ovmf-vars.fd \
  --tpm-dir /path/to/last-swtpm \
  --verify-file /path/to/gamer-profile-result.txt \
  --tag 20260606
```

Boot golden (SPICE + RustDesk forwards + persistent firmware):

```bash
nix run .#boot-windows-golden
# or explicitly:
nix run .#test-windows-qemu -- --boot-target \
  --target ~/win-kit-staging/golden/win11-pro-gamer-*.qcow2 \
  --payload-dir ~/win-kit-staging \
  --ovmf-vars-persist ~/win-kit-staging/golden/ovmf-vars.fd \
  --tpm-dir ~/win-kit-staging/golden/swtpm \
  --user-net --open-spice
```

Inside guest after boot — validation + remote stack:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\gamer_verify.ps1
```

`quick_fix.ps1` also runs `install_virtio_win.ps1`, `install_rustdesk.ps1`,
`install_sunshine.ps1` when present on the payload media.

Host RustDesk connect (after guest install):

```bash
nix run .#rustdesk-windows-qemu
```

Moonlight: connect to `127.0.0.1` after `install_sunshine.ps1` completes (demo
quality in VM — software encode, no GPU passthrough).

### Physical vs QEMU

| Action | QEMU | Physical USB |
|--------|------|--------------|
| Install | `test-windows-qemu --iso --fresh` | `write-windows-usb.sh` |
| Payload scripts | `--payload-dir` ISO | USB root / `D:\` |
| RustDesk | `--user-net` + host script | LAN after `quick_fix.ps1` |
| Sunshine / Moonlight | localhost forwards | LAN IP of target |
| Golden seal | `seal-windows-golden.sh` | N/A |

## 2. Write the installer USB

```bash
lsblk -o NAME,SIZE,MODEL,TRAN,LABEL          # identify the target stick
sudo ./scripts/write-windows-usb.sh --device /dev/sdX \
     --iso ~/win-kit-staging/Windows.iso --payload ~/win-kit-staging
```

Builds: GPT → FAT32 ESP `WIN_INSTALL` → ISO contents (minus `install.wim`) →
`install.swm` split → `autounattend.xml` at root → payload (`Installers/`,
`Drivers/`, `quick_fix.ps1`). Verifies `efi/boot/bootx64.efi` + `sources/install.swm`.

Optional realism check (snapshot=on, stick untouched):

```bash
sudo ./scripts/test-windows-qemu.sh --device /dev/sdX --check-media
```

## 3. BIOS FlashBack USB (separate Kingston stick)

Flash the board's latest BIOS **before** installing the OS (stable EXPO/microcode).

```bash
sudo ./scripts/build-firmware-usb.sh --device /dev/sdY \
     --bios-zip ~/win-kit-staging/firmware/<ASUS-B850-E>.zip
```

Single FAT32 partition, `.CAP` renamed to `A5653.CAP` (ASUS TUF B850-E WIFI).
Follow the printed FlashBack button steps.

## 4. On the hardware

1. (New build) FlashBack the BIOS first.
2. In firmware: **Secure Boot ON**, **TPM/PTT/fTPM ON**, boot mode UEFI.
3. F12 / boot menu → pick the **UEFI:** USB entry (not a legacy row).
4. Unattended install runs (wipes Disk 0 per the answer file).
5. After first boot, run the payload from the USB:
   `powershell -ExecutionPolicy Bypass -File D:\quick_fix.ps1`
   (de-bloat, apps, context menus).
6. Install drivers in order: **AMD chipset → Radeon Adrenalin → NIC/audio**
   (`windows-kit/driver-manifest.md` has silent switches).

## Per-machine notes

- **Friend's new build** (Ryzen 9850X3D / ASUS B850-E / RX 9070 XT): native
  UEFI + TPM 2.0 + Secure Boot — the happy path. FlashBack BIOS first.
- **Dell laptop** (the one that failed Kali): the Kali failure was **UEFI on this
  hardware class** (Legacy worked — see `lacie-multiboot-kali-notes.md`). Win11
  has **no Legacy/MBR path**, so:
  - Try the UEFI USB entry with **Secure Boot OFF first** to isolate a key/shim
    issue; re-enable Secure Boot once it boots (needed for anti-cheat).
  - If the firmware truly can't UEFI-boot removable media, Win11 isn't viable
    there — fall back to **Win10** (supports Legacy/MBR) or fix the firmware.
  - Confirm the Dell has TPM 2.0 (older units may be 1.2/none) before promising
    an anti-cheat-capable install.

## Out of scope / notes

- **Activation:** install unactivated; the `autounattend` key is an edition
  selector only. MAS 3.11 is the operator's call — not staged or auto-run here.
- **DISM driver injection** is Windows-only; on Linux we stage drivers + use
  `$WinpeDriver$` / autounattend driver paths instead.
- **Vendor driver auto-download** is best-effort (Cloudflare/JS) — the fetch
  script prints URLs and extracts whatever you download manually.
