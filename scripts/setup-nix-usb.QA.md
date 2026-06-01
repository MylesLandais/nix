# Nix USB QA Checklist

## Goal

Validate the GRUB-first lacie recovery USB workflow:

- `LACIE_EFI` (p1) boots GRUB with loopback ISO entries
- `lacie_isos` (p2) holds installer ISOs
- `live_nix` (p3) provides persistent NixOS root
- `persistent_data` (p4) holds bulk cross-machine data

## Preflight

- Confirm target disk: `lsblk -o NAME,SIZE,LABEL,MODEL,SERIAL,TRAN`
- Script syntax: `bash -n ./scripts/setup-nix-usb.sh`
- QEMU script syntax: `bash -n ./scripts/test-usb-qemu.sh`
- Tools: `nix-shell -p parted ntfs3g exfatprogs dosfstools wget gnutar curl git rsync grub2`

## Disk setup

```bash
sudo ./scripts/setup-nix-usb.sh --device /dev/sdX --force-rebuild
# or GRUB-only refresh after ISO changes:
sudo ./scripts/setup-nix-usb.sh --device /dev/sdX --grub-only
```

Confirm layout with `lsblk -f /dev/sdX`:

| Partition | Label | Filesystem |
|-----------|-------|------------|
| p1 | `LACIE_EFI` | vfat |
| p2 | `lacie_isos` | exfat |
| p3 | `live_nix` | ext4 |
| p4 | `persistent_data` | ntfs |

Confirm `iso-entries.cfg` on p1 contains `configfile (loop)` entries for staged ISOs.

## QEMU boot QA (local feedback loop)

Use QEMU on cerberus to test boot paths without switching machines. See also `scripts/extract-installer-boot.sh` and `docs/cluster/installer-iso.md`.

### ISO build cost (avoid unnecessary rebuilds)

| Change | Full ISO rebuild? | Test path |
|--------|-------------------|-----------|
| `boot.initrd.*`, kernel modules | Yes (initrd inside ISO) | **toplevel** + Tier 1 |
| GRUB entries / `iso-entries.cfg` | No | `--grub-only` + Tier 2 |
| Desktop / HM dotfiles in installer-iso | Yes (for live session) | Defer until boot loop passes |

**Fast initrd loop:**

```bash
./scripts/extract-installer-boot.sh --build
# run the printed Tier 1 command
```

**Full ISO loop** (only after Tier 1+2 pass, or before hardware flash):

```bash
nix build .#packages.x86_64-linux.installer-iso
cp -v result/iso/*.iso /path/to/lacie_isos/home-office-installer.iso.new && sync
mv /path/to/lacie_isos/home-office-installer.iso.new /path/to/lacie_isos/home-office-installer.iso
sudo ./scripts/setup-nix-usb.sh --device /dev/sdX --grub-only
```

### Tier 1 — initrd findiso (~2 min)

Tests legacy initrd `findiso=` without GRUB. Use injected kernel/initrd from toplevel build.

```bash
sudo ./scripts/test-usb-qemu.sh --iso-only --serial --auto-device \
  --kernel "$(readlink -f /tmp/installer-toplevel/kernel)" \
  --initrd "$(readlink -f /tmp/installer-toplevel/initrd)" \
  --log-file /tmp/tier1.log
```

Success: serial log shows findiso resolution and Stage 1 init.

### Tier 2 — GRUB loopback (~5 min, daily driver)

```bash
sudo ./scripts/test-usb-qemu.sh --partitions --serial --auto-device \
  --log-file /tmp/tier2.log
```

Success: GRUB menu → ISO entry → same initrd milestones as Tier 1.

### Tier 3 — full USB passthrough (~10+ min)

```bash
sudo ./scripts/test-usb-qemu.sh --device /dev/sdX --serial \
  --log-file /tmp/tier3.log
```

Success: matches Tier 2 via OVMF USB boot menu.

### Tier 4 — SSH ingress smoke (pre-flash gate, ~5-8 min)

Boots the staged ISO via the same initrd findiso path Tier 1 uses, with
user-mode SLIRP networking and `hostfwd 127.0.0.1:2222 -> guest 22`. From the
host, ssh into the guest and confirm the live image really accepts the
cerberus key. Required before flashing to physical hardware.

```bash
sudo ./scripts/test-usb-qemu.sh --ssh-smoke --auto-device \
  --ssh-key ~/.ssh/id_ed25519 --ssh-user warby --ssh-timeout 240
```

Success: `PASS: ssh+hostname == home-office-installer` and `/etc/iso-build-info`
contents printed to the log. Failure prints the last 60 lines of the QEMU
serial log so you can see whether sshd never came up vs. key was rejected.

### Automated pass check

```bash
sudo ./scripts/test-usb-qemu.sh --iso-only --serial --auto-device \
  --kernel ... --initrd ... \
  --expect 'Stage 1' --timeout 300 --log-file /tmp/tier1.log
```

Flake apps: `nix run .#test-usb-qemu -- --help`

### Single-command deploy

```bash
# Build, stage, GRUB refresh, then run Tier 4 SSH smoke as a pre-flash gate.
nix run .#iso-deploy -- --device /dev/sda --smoke

# Skip rebuild when iterating on staging only:
nix run .#iso-deploy -- --device /dev/sda --skip-build /tmp/installer-iso/iso/*.iso --smoke
```

`iso-deploy` aborts with non-zero exit on smoke failure so CI / automation can
fan out without flashing a broken ISO.

Preflight without sudo: `./scripts/test-usb-qemu.sh --dry-run --auto-device --partitions --serial`

## Hardware boot validation

- Plug LaCie into target laptop
- F12 → LaCie → GRUB menu
- Select installer ISO entry
- Boot succeeds to live environment
- Mount `LABEL=live_nix` and confirm repo/recovery dirs

## Failure capture

Record:

- console / serial log
- `lsblk -f`
- `parted -s /dev/sdX unit MiB print`
- `.nix-usb-logs/<timestamp>/` if from setup script
