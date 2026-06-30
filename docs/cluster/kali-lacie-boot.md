# Kali live boot from lacie

Deploy Kali immediately on cluster laptops via the LaCie GRUB menu. Use
**home-office-installer.iso** only for NixOS install / SSH recovery; Kali is the
primary pentest and live-session path.

## Boot path

1. UEFI: Secure Boot **OFF**, UEFI mode (not CSM).
2. F12 → LaCie USB.
3. Lacie GRUB → **Kali Linux …** (submenu).
4. Kali’s own menu appears (live, failsafe, forensic, persistence, installer).

The lacie **submenu** uses loopback + `root=(loop)` + `source /boot/grub/grub.cfg`
for live / persistence / failsafe. A separate top-level **Graphical Install**
entry passes `findiso=` to the installer kernel.

### Installer: "incorrect installation media detected"

The installer inside Kali’s submenu does **not** pass `findiso=` and often cannot
read the ISO on the **exFAT** `lacie_isos` partition. You may see:

> The detected media could not be used for installation / incorrect installation media detected

**Use one of these (in order):**

1. Lacie GRUB → **Kali … (Graphical Install)** — dedicated entry with `findiso=`
   (may still fail on exFAT; try step 2 if it does).

2. Stage a copy on **ext4** `live_nix`, refresh GRUB, boot **Kali Graphical Install (ext4 on live_nix)**:

   ```bash
   sudo ./scripts/stage-kali-for-install.sh
   nix-shell -p grub2_efi --run 'sudo ./scripts/setup-nix-usb.sh --device /dev/sdb --grub-only'
   ```

3. **Dedicated USB** (recommended when loopback keeps failing): write the **installer** ISO
   directly — no lacie GRUB layer:

   ```bash
   lsblk -o NAME,SIZE,MODEL,TRAN,LABEL
   sudo ./scripts/write-kali-usb.sh \
     --device /dev/sdX \
     --iso ~/Downloads/kali-linux-2026-W19-installer-amd64.iso
   ```

   Use `kali-linux-*-installer-amd64.iso`, not the 16G live-everything image, for
   bare-metal installs. Boot → **Graphical install** at Kali’s own GRUB menu.

4. **Live only** (no d-i): submenu → **Live system (amd64)** or persistence entry for pentest sessions.

## Writable sessions (persistence)

Default Kali live is read-only squashfs with a RAM overlay. WiFi profiles and
other writes are lost on reboot unless you use persistence.

1. Create an ext4 partition labeled `persistence` (only if unallocated space
   exists at the end of the disk, or after shrinking `lacie_isos`):

   ```bash
   # Check free space first:
   sudo parted -s /dev/sdb unit GiB print free

   sudo ./scripts/setup-kali-persistence.sh --device /dev/sdb --size-gib 32
   # Optional full RW root (more wear on USB):
   sudo ./scripts/setup-kali-persistence.sh --device /dev/sdb --size-gib 32 --union
   ```

2. Refresh GRUB if ISOs changed:

   ```bash
   nix-shell -p grub2_efi --run 'sudo ./scripts/setup-nix-usb.sh --device /dev/sdb --grub-only'
   ```

3. Boot: Kali submenu → **Live system with USB persistence**.

4. Verify: `touch /root/persist-test`, reboot, confirm the file exists.

## WiFi on target laptops

```bash
nmcli device wifi list
nmcli device wifi connect 'SSID' password 'PASS'
```

If the NIC does not appear:

```bash
lspci -k | grep -A3 -i network
dmesg | grep -i firmware
```

The “everything” ISO includes most firmware; some Dell NICs still need
non-free blobs — install temporarily in the live session or use persistence so
`apt` changes survive reboot.

## ISO on lacie

| File | Role |
|------|------|
| `kali-linux-*-live-*.iso` | Primary live / install / pentest |
| `home-office-installer.iso` | NixOS cluster install shim |
| `latest-nixos-graphical-x86_64-linux.iso` | Upstream NixOS fallback |

After adding or renaming ISOs:

```bash
nix-shell -p grub2_efi --run 'sudo ./scripts/setup-nix-usb.sh --device /dev/sdb --grub-only'
```

## Preflight (cerberus)

```bash
./scripts/recovery-preflight.sh --device /dev/sdb
```

Expect Kali block in `iso-entries.cfg`: `submenu`, `set root=(loop)`, `source /boot/grub/grub.cfg`.

## UEFI vs Legacy

On cluster OptiPlex-class hardware, **both lacie and a dedicated `dd` Kali stick**
have booted only under **Legacy/CSM**, not pure UEFI. That points to **firmware,
Secure Boot, and which F12 entry you pick** (`UEFI: …` vs legacy USB), not only
lacie GRUB. See [lacie-multiboot-kali-notes.md](lacie-multiboot-kali-notes.md).

**Working path today:** Legacy ON → F12 → non-UEFI USB entry → Kali menu.

**UEFI debug:** Secure Boot OFF, UEFI-only mode, F12 → **`UEFI: <stick>`**,
rear USB 2.0; on cerberus verify `lsblk` shows vfat ESP + `EFI/BOOT/BOOTX64.EFI`
after `write-kali-usb.sh`.

## Related

- [lacie-multiboot-kali-notes.md](lacie-multiboot-kali-notes.md) — multiboot vs dd lessons, UEFI backlog
- [hosts/lacie/readme.md](../../hosts/lacie/readme.md) — disk layout
- [installer-iso.md](installer-iso.md) — home-office installer ISO
- [recovery-hardware-qa.md](recovery-hardware-qa.md) — OptiPlex hardware drills
