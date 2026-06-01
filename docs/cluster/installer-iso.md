# home-office Installer ISO

Live USB used to bring up new staging-cluster nodes. Built from `modules/hosts/installer-iso/default.nix`. Booted from lacie via GRUB loopback off the `lacie_isos` partition.

## What's in it

- Hyprland session with the full home-manager dotfile stack (gated on `host.desktop = "hyprland"`, forced in the ISO override).
- SDDM autologin into warby's Hyprland session.
- `warby` and `kali (guest)` users; both get `modules/home.nix` via home-manager.
- SSH on, password auth off, cerberus + warbpad keys pre-seeded.
- Imaging tooling: `parted`, `gptfdisk`, `qemu_full`, `ntfs3g`, `smartmontools`, `cosmic-files`, plus `bootstrap-lacie` aliased as `nix-install`.
- **Legacy (non-systemd) initrd** — required for GRUB loopback boot via `findiso=` (systemd initrd cannot locate an ISO file on another partition).

## Build iteration (avoid unnecessary full ISO rebuilds)

| Step | Command | Cost |
|------|---------|------|
| Boot-path only | `nix build .#nixosConfigurations.installerIso.config.system.build.toplevel` | Fast — no squashfs/ISO packaging |
| Extract boot artifacts | `./scripts/extract-installer-boot.sh --build` | Prints Tier 1 QEMU command |
| Full ISO | `nix build .#packages.x86_64-linux.installer-iso` | ~14 GB, 30–60+ min |
| GRUB regen | `setup-nix-usb.sh --device /dev/sdX --grub-only` | Seconds |
| One-shot deploy | `nix run .#iso-deploy -- --device /dev/sda --smoke` | Build + stage + GRUB + Tier 4 SSH |

**Rule of thumb:** boot-path changes → toplevel + Tier 1 QEMU; GRUB changes → `--grub-only` + Tier 2; full ISO only before hardware flash or live-session changes. Before any hardware flash run **Tier 4 SSH smoke** so a broken-key ISO never lands on lacie.

See [`scripts/setup-nix-usb.QA.md`](../../scripts/setup-nix-usb.QA.md) for the tiered QEMU test workflow (including Tier 4).

## Build provenance

Every ISO bakes `/etc/iso-build-info` containing:

- flake git rev + dirty marker
- nixpkgs flake rev
- sha256 fingerprints of every `authorized_keys` entry that warby and root accept

The live `getty.helpLine` prints `Home Office NixOS installer (rev <short>)` so the tty shows which commit is running before login. From cerberus:

```bash
ssh -i ~/.ssh/id_ed25519 -o IdentitiesOnly=yes warby@<dhcp-ip> cat /etc/iso-build-info
```

## Build and stage to lacie

Prefer the one-shot deploy:

```bash
nix run .#iso-deploy -- --device /dev/sda --smoke
```

This builds [`packages.x86_64-linux.installer-iso`](../../modules/hosts/installer-iso/default.nix), stages atomically via [`scripts/stage-installer-iso.sh`](../../scripts/stage-installer-iso.sh) (which also refreshes GRUB), and then runs the Tier 4 QEMU SSH smoke. Exit code is non-zero if the smoke fails so automation never proceeds on a broken ISO.

Manual fallback:

```bash
nix build .#packages.x86_64-linux.installer-iso
cp -v result/iso/*.iso /run/media/warby/lacie_isos/home-office-installer.iso.new
sync
mv /run/media/warby/lacie_isos/home-office-installer.iso.new /run/media/warby/lacie_isos/home-office-installer.iso
sync
sudo ./scripts/setup-nix-usb.sh --device /dev/sda --grub-only
```

Unmount before pulling the USB:

```bash
udisksctl unmount -b /dev/sda1   # LACIE_EFI
udisksctl unmount -b /dev/sda2   # lacie_isos
udisksctl unmount -b /dev/sda3   # live_nix
udisksctl unmount -b /dev/sda4   # persistent_data
```

## Other ISOs on lacie

| File | Purpose |
|------|---------|
| `home-office-installer.iso` | This ISO — cluster onboarding |
| `latest-nixos-graphical-x86_64-linux.iso` | Upstream graphical installer, fallback |
| `kali-linux-*-live-*.iso` | Kali live (GRUB chains to ISO's own menu) |

After copying a new ISO onto `lacie_isos`, refresh GRUB only:

```bash
sudo ./scripts/setup-nix-usb.sh --device /dev/sda --grub-only
```

## Onboarding a new node from this ISO

See [recovery-hardware-qa.md](recovery-hardware-qa.md) for OptiPlex recovery drills (boot lacie → SSH → `nixos-enter`).

1. Boot lacie GRUB menu → select `home-office-installer.iso`. Autologin lands warby in Hyprland.
2. On tty: `cat /etc/iso-build-info` confirms which commit shipped.
3. Capture identity / disks before partitioning:
   - `sudo dmidecode -s system-serial-number` (lowercase → hostname)
   - `lsblk -d -o NAME,SIZE,MODEL,SERIAL` (pick disks by serial, not letter)
   - `ip -o link`, `ip -4 addr` (NIC name + DHCP IP)
4. From cerberus: `ssh warby@<dhcp-ip>` works on first boot — keys are already trusted. The cluster + installer hostnames bypass the Bitwarden SSH agent via the [`modules/features/ssh-bitwarden.nix`](../../modules/features/ssh-bitwarden.nix) `Host` block, so this works even with the vault locked.
5. Run `nix-install` (alias of `bootstrap-lacie`) for guided partition + install.
6. After install, scaffold `modules/hosts/<tag>/` and add a node block to `colmena.nix`. See `docs/cluster/colmena.md`.

## When to rebuild the ISO

Only when the live-boot experience changes — new packages baked in, keybind tweaks, key rotations, or onboarding-flow scripts. Per-node config deploys via Colmena after install; it does not require an ISO rebuild.
