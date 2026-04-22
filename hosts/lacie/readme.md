# lacie — Portable NixOS Workstation

A reproducible Hyprland workstation that runs directly from a LaCie 5TB Rugged USB-C drive.
Plug into any x86_64 UEFI machine, boot, and land in your environment.

## Disk Layout

| Partition | Label | Size | Filesystem | Purpose |
|-----------|-------|------|------------|---------|
| p1 | `Ventoy` | 64 GiB | exFAT | Ventoy ISO boot partition — holds NixOS graphical installer ISO |
| p2 | `VTOYEFI` | 32 MiB | FAT16 | Ventoy EFI + systemd-boot entries |
| p3 | `live_nix` | 500 GiB | ext4 | NixOS system root — kernel, store, config, persistent state |
| p4 | `persistent_data` | ~4 TiB | NTFS | Bulk storage — music, backups, shared files, secrets |

The flake config and nix store live on `live_nix`. `persistent_data` mounts at `/mnt/data`.

## Required UEFI Settings (target machine)

- Secure Boot: **OFF**
- Boot mode: **UEFI** (not Legacy/CSM)
- Boot order or one-time menu: **F12** on Dell hardware

## Building the Drive from Scratch

Run `setup-nix-usb.sh` from the host machine (cerberus or any Linux system with the drive attached):

```bash
nix-shell -p parted ntfs3g exfatprogs dosfstools wget gnutar curl git rsync --run \
  "sudo ./scripts/setup-nix-usb.sh --device /dev/sdX --force-rebuild --skip-repo-sync"
```

This installs Ventoy with reserved space, creates the extra partitions, formats them, and stages the latest NixOS ISO.

## Bootstrapping the NixOS Install

Boot the target machine from the NixOS ISO via the Ventoy menu, then run:

```bash
# From the live ISO session (network required):
curl -fsSL https://raw.githubusercontent.com/MylesLandais/nix/main/scripts/bootstrap-lacie.sh \
  | sudo bash
```

Or clone the repo and run locally:

```bash
git clone https://github.com/MylesLandais/nix.git /tmp/nix
sudo /tmp/nix/scripts/bootstrap-lacie.sh
```

The script handles: partition detection, mounting, hardware-configuration.nix generation, repo clone, and `nixos-install`. See `scripts/bootstrap-lacie.sh` for flags (`--dry-run`, `--skip-clone`, `--device`).

## Hermes API Key (AI Assistant)

Hermes reads its API key from `persistent_data` so it survives rebuilds:

```bash
mkdir -p /mnt/data/secrets
echo 'ANTHROPIC_API_KEY=sk-ant-...' > /mnt/data/secrets/hermes.env
chmod 600 /mnt/data/secrets/hermes.env
```

Do this before rebooting after install, or on first boot before running `nixos-rebuild`.

## Day-to-Day Usage

**Rebuild after config changes:**
```bash
sudo nixos-rebuild switch --flake /nix-configs#lacie
```

**Update flake inputs:**
```bash
cd /nix-configs
nix flake update
sudo nixos-rebuild switch --flake /nix-configs#lacie
```

**Config repo location on disk:** `/nix-configs` (symlinked from `live_nix` root)

## SSH and Git Auth

The default install has no SSH keys. Options:

- Copy `~/.ssh/` from cerberus via Tailscale after first boot
- Generate a new USB-specific keypair: `ssh-keygen -t ed25519 -C "lacie"`
- Vault/trust bootstrap with cerberus — planned, not yet implemented

## Vault / Trust Bootstrap (Planned)

Future work: establish a trust relationship between lacie and cerberus so secrets can sync over Tailscale without manual key copying. Likely via agenix with a lacie-specific age key stored on `persistent_data`.

## Flake Target

```
nixosConfigurations.lacie
```

Build without applying:
```bash
nix build /nix-configs#nixosConfigurations.lacie.config.system.build.toplevel
```
