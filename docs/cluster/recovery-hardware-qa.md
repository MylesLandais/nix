# Remote Recovery Hardware QA

Validate the home-office installer ISO as a **live recovery environment** on cluster OptiPlex nodes, booted from lacie (or fallback USB).

Recovery path B: [`.claude/commands/rescue-ssh.md`](../../.claude/commands/rescue-ssh.md). **Do not run `nix-install`** unless reimaging is intentional.

## When to use

- Prove lacie GRUB loopback boots on real Dell OptiPlex 7050 hardware
- Confirm cerberus can `ssh root@<live-ip>` / `ssh warby@<live-ip>` without password paste
- Drill `mount` + `nixos-enter` against the on-disk NixOS root
- Reboot back to the installed system unchanged

## Cluster baseline (from hardware-configuration.nix)

| Host | LAN (typical) | Root filesystem | Boot | Data |
|------|---------------|-----------------|------|------|
| **94tl0m2** | `192.168.0.212` (`94tl0m2`) | `LABEL=nixos` on **nvme0n1** (PM981) | `LABEL=BOOT` | `LABEL=data` on **sda** (XFS `/srv/data`) |
| **95qmom2** | `192.168.0.49` / Tailscale `dell-potato` | **sda3** ext4 UUID `89395068-...` | sda1 vfat | sdb1 XFS `/srv/data` |

Run `./scripts/recovery-preflight.sh` on cerberus to refresh live baseline when nodes are up.

## Pre-flight (cerberus, lacie still attached)

```bash
./scripts/recovery-preflight.sh
./scripts/recovery-preflight.sh --host 94tl0m2
```

Checklist:

- [ ] `lsblk -f /dev/sda` — `LACIE_EFI`, `lacie_isos`, `live_nix`, `persistent_data`
- [ ] `home-office-installer.iso` on `lacie_isos` (~15 GB)
- [ ] `/boot/grub/iso-entries.cfg` contains `configfile (loop)` + `Home Office Installer`
- [ ] Optional: `sudo ./scripts/test-usb-qemu.sh --dry-run --partitions --serial --auto-device`
- [ ] Baseline SSH to target host succeeds (Bitwarden SSH agent unlocked)

## Hardware boot — 94tl0m2 first

1. Plug lacie into the OptiPlex. UEFI: Secure Boot **OFF**, UEFI (not CSM).
2. F12 → LaCie / removable disk.
3. GRUB → **Home Office Installer** (30s default).
4. Second GRUB → **NixOS Installer** → Hyprland autologin as `warby`.

| Result | Action |
|--------|--------|
| Pass | Continue to SSH verification |
| GRUB rescue / blank | Try **Latest Nixos Graphical** on lacie |
| Still fails | Fallback: `dd` ISO to a small USB (see below) |

### Fallback: single-purpose USB

```bash
# On cerberus — destructive to target USB stick only
sudo dd if=/tmp/installer-iso/iso/nixos-*.iso of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

Boot target from that stick (not lacie). Still validates recovery session.

## Recovery verification (from cerberus)

After live desktop is up, on the console run `ip -4 addr` for DHCP IP, then on cerberus:

```bash
./scripts/recovery-verify.sh --host 192.168.0.212
# or after boot:
./scripts/recovery-verify.sh --host <dhcp-ip> --root LABEL=nixos
```

Manual steps on the **live session** (if not using verify script remote commands):

```bash
lsblk -f
sudo mount /dev/disk/by-label/nixos /mnt    # 94tl0m2 example
sudo nixos-enter --root /mnt
exit
sudo umount /mnt
```

Pass criteria:

- [ ] `ssh root@<ip>` — installer ISO allows root key login
- [ ] `ssh warby@<ip>` — warby key login
- [ ] `nixos-enter` succeeds on correct root partition
- [ ] Reboot without lacie → normal `ssh warby@94tl0m2` works

## Optional: colmena after recovery

Only when booted to **installed disk**, not from live ISO:

```bash
cd ~/.config/nixos
nix run nixpkgs#colmena -- apply switch --on 94tl0m2 --impure
```

## Repeat on 95qmom2

Run the same checklist after 94tl0m2 passes. Use root `sda3` or `by-uuid/89395068-a5be-4b51-af6d-856a77ba5fa2`. **Do not run `nix-install`** on the data-core node during recovery drills.

## Capture template

Save under `.nix-usb-logs/recovery-<host>-<YYYYMMDD>.md`:

```markdown
# Recovery test — <host> — <date>

- Boot path: lacie GRUB / fallback USB / upstream ISO
- Time to GRUB menu:
- Time to Hyprland desktop:
- Live IP:
- SSH root: pass/fail
- SSH warby: pass/fail
- Root mounted: /dev/...
- nixos-enter: pass/fail
- Reboot to installed OS: pass/fail
- Notes:
```

## Related

- [installer-iso.md](installer-iso.md) — build and stage ISO
- [setup-nix-usb.QA.md](../../scripts/setup-nix-usb.QA.md) — QEMU tiered boot QA
- [colmena.md](colmena.md) — deploy after repair
