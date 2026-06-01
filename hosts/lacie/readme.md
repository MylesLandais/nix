# lacie — Portable NixOS Workstation

A reproducible Hyprland workstation that runs directly from a LaCie 5TB Rugged USB-C drive.
Plug into any x86_64 UEFI machine, boot, and land in your environment.

## Disk Layout

| Partition | Label | Size | Filesystem | Purpose |
|-----------|-------|------|------------|---------|
| p1 | `LACIE_EFI` | 1 GiB | FAT32 | GRUB EFI + Kanagawa theme |
| p2 | `lacie_isos` | 63 GiB | exFAT | ISO files for GRUB loopback boot |
| p3 | `live_nix` | 500 GiB | ext4 | NixOS system root — kernel, store, config |
| p4 | `persistent_data` | ~4 TiB | NTFS | Bulk storage — music, backups, secrets |

The flake config and nix store live on `live_nix`. `persistent_data` mounts at `/mnt/data`.

## Required UEFI Settings (target machine)

- Secure Boot: **OFF**
- Boot mode: **UEFI** (not Legacy/CSM)
- Boot order or one-time menu: **F12** on Dell hardware

## Building the Drive from Scratch

Run `setup-nix-usb.sh` from cerberus (or any Linux system with the drive attached):

```bash
nix-shell -p parted ntfs3g exfatprogs dosfstools wget gnutar curl git rsync grub2 --run \
  "sudo ./scripts/setup-nix-usb.sh --device /dev/sdX --force-rebuild --skip-repo-sync"
```

Refresh GRUB entries after ISO changes (no repartition):

```bash
sudo ./scripts/setup-nix-usb.sh --device /dev/sda --grub-only
```

Scans `lacie_isos` (`/run/media/warby/lacie_isos` when automounted) and writes
`/boot/grub/iso-entries.cfg` on `LACIE_EFI`. Re-run after adding or renaming any
`*.iso` (e.g. `kali-linux-2026.1-live-everything-amd64.iso`). Kali/Debian images
chain-load their own `/boot/grub/grub.cfg` via loopback (`iso_path`).

QA: [`scripts/setup-nix-usb.QA.md`](../../scripts/setup-nix-usb.QA.md).

## Boot testing in QEMU (cerberus)

Test boot paths locally without switching machines. Full checklist: [`scripts/setup-nix-usb.QA.md`](../../scripts/setup-nix-usb.QA.md).

```bash
# Tier 1 — initrd findiso (fastest; use fresh toplevel boot artifacts)
./scripts/extract-installer-boot.sh --build

# Tier 2 — GRUB loopback (daily driver)
sudo ./scripts/test-usb-qemu.sh --partitions --serial --auto-device

# Tier 3 — full USB passthrough
sudo ./scripts/test-usb-qemu.sh --device /dev/sda --serial
```

Flake: `nix run .#test-usb-qemu -- --help`

## Bootstrapping the NixOS Install

Boot the target machine from an ISO via the GRUB menu on lacie, then run:

```bash
sudo nix-install   # alias of bootstrap-lacie (from the live ISO)
```

Or from a cloned repo:

```bash
sudo ./scripts/bootstrap-lacie.sh
```

The script handles: partition detection, mounting, hardware-configuration.nix generation, repo clone, and `nixos-install`. See `scripts/bootstrap-lacie.sh` for flags.

## Hermes API Key (AI Assistant)

Hermes reads its API key from `persistent_data` so it survives rebuilds:

```bash
mkdir -p /mnt/data/secrets
echo 'ANTHROPIC_API_KEY=sk-ant-...' > /mnt/data/secrets/hermes.env
chmod 600 /mnt/data/secrets/hermes.env
```

## Day-to-Day Usage

**Rebuild after config changes:**

```bash
sudo nixos-rebuild switch --flake /nix-configs#lacie
```

**Config repo location on disk:** `/nix-configs` (symlinked from `live_nix` root)

## SSH and Git Auth

- Copy `~/.ssh/` from cerberus via Tailscale after first boot
- Generate a USB-specific keypair: `ssh-keygen -t ed25519 -C "lacie"`
- Vault/trust bootstrap with cerberus — planned, not yet implemented

## Flake Target

```
nixosConfigurations.lacie
```

Build without applying:

```bash
nix build /nix-configs#nixosConfigurations.lacie.config.system.build.toplevel
```
