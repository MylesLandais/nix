# FOSS GRUB multiboot USB

A transparent, fully-FOSS multiboot installer USB: a self-built `grub-mkstandalone`
EFI + a plain, editable `grub.cfg`. No agFM, no Ventoy, no vendor blobs. Boots
Windows 11 and NixOS installers from one stick. Builder:
`scripts/setup-grub-multiboot-usb.sh`.

## Why this (and not agFM / Ventoy / the old lacie GRUB)

- **Transparency:** you can read every line — the GRUB EFI is built from nixpkgs
  `grub2_efi`, the menu is a 20-line `grub.cfg` you can edit on the stick.
- **No third-party shims** that can be revoked; clean path to TPM/measured boot
  if you later sign with your own keys.
- The old bespoke lacie GRUB and Ventoy/agFM all fought us under Secure Boot
  (MOK prompts, loopback Windows failures). This sidesteps them.

## Secure Boot reality

This stick runs **Secure Boot OFF** — its GRUB EFI is unsigned, and it must boot
**arbitrary machines** (a friend's build, the Dell) whose firmware won't trust
our keys. That's fine:

- **Windows 11** installs fine SB-off. **Re-enable Secure Boot in firmware after
  install** — Windows' own bootmgr is MS-signed and boots SB-on natively (needed
  for TPM/anti-cheat).
- **NixOS installer** is unsigned regardless of loader; it needs SB-off (or our
  own enrolled keys — deferred, see bottom).
- Signing the GRUB EFI with `sbctl` only helps on machines where our keys are
  enrolled (our own boxes), so it's deferred — low value for arbitrary targets.

## Layout

```
p1  FAT32  ~1G   ESP (ef00)  -> \EFI\BOOT\BOOTX64.EFI (grub) + \boot\grub\grub.cfg
p2  NTFS   rest  PAYLOAD     -> EXTRACTED Win11 ISO at root + nixos-*.iso + autounattend.xml
```

Windows files MUST be at the **NTFS root**: bootmgr's BCD reads `\sources\boot.wim`
and `\boot\bcd` relative to the volume root. NTFS is required for the >4 GB
`install.wim` and so GRUB can `chainload` the bootmgr (GRUB **loopback** of a
Windows ISO does *not* work for Setup — that's what defeated the old lacie GRUB).

## Build

```bash
lsblk -o NAME,SIZE,MODEL,TRAN,LABEL                 # identify the stick (e.g. /dev/sda)
sudo ./scripts/setup-grub-multiboot-usb.sh --device /dev/sda \
     --win-iso ~/Downloads/Win11_24H2_English_x64.iso \
     [--nixos-iso ~/Downloads/nixos-minimal.iso]
```

Steps the script runs: GPT (FAT32 ESP + NTFS payload) → `grub-mkstandalone`
(modules baked in: `part_gpt fat ntfs chain loopback linux configfile …`, early
config `configfile`s the editable `grub.cfg`) → extract Win11 ISO to the NTFS
root → copy `windows-kit/autounattend.xml` → (optional) copy the NixOS ISO and
auto-generate its loopback `findiso=` entry from the ISO's own `grub.cfg`.

Needs `grub2_efi` + `ntfs3g` (added to `modules/packages.nix`; `/nix-switch` to
get them on PATH — otherwise the script resolves `grub2_efi` via `nix build`).

## grub.cfg (what lands on the ESP)

```grub
set timeout=15
search --no-floppy --label PAYLOAD --set=payload

menuentry "Install Windows 11 (chainload bootmgr)" {
  insmod part_gpt; insmod ntfs; insmod chain
  set root=$payload
  chainloader ($payload)/efi/boot/bootx64.efi
}
# NixOS entry (if --nixos-iso): GRUB loopback + findiso=, params read from the ISO.
```

Edit it directly on the FAT32 partition — no rebuild of the EFI needed.

## Validate in QEMU (no hardware)

USB-passthrough under plain OVMF, Secure Boot off (snapshot=on, stick untouched):

```bash
sudo ./scripts/test-windows-qemu.sh --device /dev/sda --no-secureboot --check-media
```

Pass if: OVMF → our GRUB menu → "Install Windows 11" → Windows Setup (language
screen); "Install NixOS" → NixOS stage-1. If Windows chainload errors, confirm the
ISO contents are at the **NTFS root** (`/sources/install.wim`, `/efi/boot/bootx64.efi`).

## On the hardware

1. Firmware: **Secure Boot OFF**, UEFI (not CSM), TPM on.
2. F12 → **UEFI: <USB>** (not a legacy row) → GRUB menu.
3. Windows: unattended install runs (autounattend = local account, keeps
   TPM/SecureBoot). After first boot, run `quick_fix.ps1` from the payload.
4. **Re-enable Secure Boot** in firmware after Windows is installed.

## lacie replication (non-destructive)

Keep `live_nix` + `persistent_data`. Put the grub-standalone EFI on `LACIE_EFI`
(replacing the custom-GRUB `BOOTX64.EFI`), keep NixOS ISOs on exFAT `lacie_isos`
(loopback works on exFAT), and extract Win11 to an **NTFS** slice
(`persistent_data` or a dedicated one) since Windows bootmgr needs its files on NTFS.

## Deferred: sbctl signing (SB-on on our own boxes)

Only worthwhile for hardware where we enroll our keys. If pursued: `sbctl`
create-keys → firmware Setup Mode → `sbctl enroll-keys --microsoft` (KEEP MS keys
so Windows bootmgr + firmware still boot) → `sbctl sign` the `BOOTX64.EFI`; and
migrate cerberus to `lanzaboote` so it boots SB-on too. See `feedback-foss-boot-chain`.
