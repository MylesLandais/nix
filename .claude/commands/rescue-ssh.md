# /rescue-ssh

Recover a NixOS host that has drifted out of SSH reach (warby keys broken,
user account locked, network config wedged, etc.). Every host that imports
`modules/features/ssh-keys.nix` mirrors warby's keys to `root` with
`PermitRootLogin = "prohibit-password"`, so the recovery account is always
present in deployed configs.

## When to use

- `ssh warby@host` fails with permission denied but the host is up.
- A bad rebuild bricked warby's account.
- You need to repair `configuration.nix` on disk before the next reboot.

## Recovery paths

### A. Root key still works (most common)

```
ssh -i ~/.ssh/id_ed25519 root@<host>
```

Then either fix in place or trigger a colmena redeploy from cerberus:

```
cd ~/.config/nixos
colmena apply --on <host>
```

### B. Root key broken too — boot the installer ISO

The `installerIso` config also imports `ssh-keys.nix`, so root + warby keys
work over SSH from the live USB.

1. Boot the host off the home-office installer USB (built from
   `nix build .#nixosConfigurations.installerIso.config.system.build.isoImage`).
2. From cerberus:
   ```
   ssh root@<host-on-live-usb>
   ```
3. Mount the on-disk root and `nixos-enter`:
   ```
   mount /dev/<root-partition> /mnt
   nixos-enter --root /mnt
   ```
4. Edit `/etc/nixos` (or pull the flake) and rebuild:
   ```
   nixos-rebuild switch --flake /mnt/etc/nixos#<host>
   ```
5. Reboot off the disk.

### C. Forced reinstall via bootstrap-lacie

If the disk is unrecoverable, run `nix-install` (alias of `bootstrap-lacie`)
from the live USB to re-image into the dendritic flake.

## Verifying root recovery is wired

```
nix eval .#nixosConfigurations.<host>.config.users.users.root.openssh.authorizedKeys.keys
nix eval .#nixosConfigurations.<host>.config.services.openssh.settings.PermitRootLogin
```

Expect warby's two ed25519 keys and `"prohibit-password"`. The installer ISO
overrides to `"yes"` via `lib.mkForce` — that's intentional for first-boot
install workflows.
