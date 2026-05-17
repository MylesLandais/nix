# home-office Installer ISO

Live USB used to bring up new staging-cluster nodes. Built from `modules/hosts/installer-iso/default.nix`. Booted off a Ventoy USB ("lacie") that holds multiple ISOs.

## What's in it

- Hyprland session with the full home-manager dotfile stack (gated on `host.desktop = "hyprland"`, forced in the ISO override). Same keybinds as Cerberus: `Super+R` fuzzel, `Super+E` cosmic-files, `Super+P` cliphist.
- SDDM autologin into warby's Hyprland session (`services.displayManager.autoLogin`).
- `warby` and `kali (guest)` users; both get `modules/home.nix` via home-manager.
- SSH on, password auth off, `authorized_keys` seeded with the same cerberus + warbpad keys 95qmom2 trusts.
- Imaging tooling: `parted`, `gptfdisk`, `qemu_full`, `ntfs3g`, `smartmontools`, `cosmic-files`, plus the `bootstrap-lacie` package aliased as `nix-install`.
- Persistent journald (`services.journald.storage = "persistent"`) — no effect on the read-only ISO boot, useful once a Ventoy install lands on the `live_nix` root.

## Build and reflash

```bash
nix build .#packages.x86_64-linux.installer-iso
ls -lh result/iso/    # ~14 GB
```

The artifact name from nixpkgs is currently `nixos-<version>-x86_64-linux.iso`; the `image.fileName` override does not bind on this nixpkgs revision. Rename on copy.

Lacie's Ventoy partition auto-mounts to `/run/media/warby/Ventoy` on cerberus (exFAT, label `Ventoy`, 64 GB). Drop the new ISO in:

```bash
cp -v result/iso/*.iso /run/media/warby/Ventoy/home-office-installer.iso.new
sync
mv /run/media/warby/Ventoy/home-office-installer.iso.new /run/media/warby/Ventoy/home-office-installer.iso
sync
```

The temp-name + rename pattern keeps the existing ISO usable until the copy finishes (Ventoy reads the file at boot, so a half-written same-name file would brick a boot mid-flight).

Unmount before pulling the USB:

```bash
udisksctl unmount -b /dev/sda1
udisksctl unmount -b /dev/sda3   # live_nix, if a Ventoy install is present
udisksctl unmount -b /dev/sda4   # persistent_data, if present
```

## Other ISOs on lacie

| File | Purpose |
|------|---------|
| `home-office-installer.iso` | This ISO — cluster onboarding |
| `lacie.iso` | Older portable install (superseded) |
| `latest-nixos-graphical-x86_64-linux.iso` | Upstream graphical installer, fallback |

## Onboarding a new node from this ISO

1. Boot Ventoy → `home-office-installer.iso`. Autologin lands warby in Hyprland.
2. Capture identity / disks before partitioning:
   - `sudo dmidecode -s system-serial-number` (lowercase → hostname)
   - `lsblk -d -o NAME,SIZE,MODEL,SERIAL` (pick disks by serial, not letter)
   - `ip -o link`, `ip -4 addr` (NIC name + DHCP IP)
3. From cerberus: `ssh warby@<dhcp-ip>` works on first boot — keys are already trusted, no manual paste needed.
4. Run `nix-install` (alias of `bootstrap-lacie`) for guided partition + install, or partition by hand with `parted`/`sgdisk` and use `nixos-install` against this flake.
5. After install, scaffold `modules/hosts/<tag>/` mirroring 95qmom2 and add a node block to `colmena.nix`. See `docs/cluster/colmena.md`.

## When to rebuild the ISO

Only when the live-boot experience changes — new packages baked in, keybind tweaks, key rotations, or onboarding-flow scripts. Per-node config (postgres, seaweedfs, etc.) lives in `modules/hosts/<tag>/` and deploys via Colmena after the box is installed; it does not require an ISO rebuild.
