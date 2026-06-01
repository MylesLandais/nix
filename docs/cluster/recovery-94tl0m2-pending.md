# Recovery test — 94tl0m2 — 2026-05-24

## Hardware boot — PASS

- Boot path: **lacie GRUB** → Home Office Installer → ISO internal GRUB → Hyprland
- Initrd: `mount operation failed /findiso invalid argument` (logged; hung briefly, then continued)
- Live IP: **192.168.0.32** (DHCP; installed OS was `192.168.0.212`)
- Desktop: Hyprland, terminal OK
- `sshd`: active/running/enabled

## Cerberus SSH — root cause identified

From cerberus, `ssh warby@192.168.0.32` was denied because:

1. The staged ISO predated the canonical [`modules/features/ssh-keys.nix`](../../modules/features/ssh-keys.nix) wiring and/or got built before the keys landed on the `warby` user.
2. Cerberus's `~/.ssh/config` forced `IdentityAgent ~/.bitwarden-ssh-agent.sock` for **all** hosts, and the Bitwarden agent was down (`Connection refused`), so `~/.ssh/id_ed25519` never got offered.

Both are fixed in the **Reproducible Installer ISO Rebuild** work:

- [`modules/features/ssh-bitwarden.nix`](../../modules/features/ssh-bitwarden.nix) now has a `Host home-office-installer 94tl0m2 95qmom2 argus lacie dell-potato 192.168.0.* 100.107.*` block that pins `IdentityFile ~/.ssh/id_ed25519` + `IdentitiesOnly yes` + `IdentityAgent none`, so unattended ops work without Bitwarden.
- [`modules/hosts/installer-iso/default.nix`](../../modules/hosts/installer-iso/default.nix) bakes `/etc/iso-build-info` with the flake rev + key fingerprints so the live tty proves which keys are loaded.

## Recovery drill — pending re-flash with new ISO

Workflow (lacie must be physically reconnected before step 1):

```bash
# 1) Build, stage, GRUB refresh, Tier 4 SSH smoke — single command:
nix run .#iso-deploy -- --device /dev/sda --smoke

# 2) Plug lacie into 94tl0m2, F12 -> Home Office Installer, capture DHCP IP.
# 3) From cerberus (no Bitwarden needed thanks to ssh-bitwarden Host block):
./scripts/recovery-verify.sh --host <dhcp-ip> --root LABEL=nixos --enter

# 4) On the live console, confirm provenance:
cat /etc/iso-build-info
```

Fill in after re-flash:

- ISO build rev (from `/etc/iso-build-info`):
- Tier 4 SSH smoke: pass/fail
- Live IP:
- SSH root: pass/fail
- SSH warby: pass/fail
- Root mounted: `/dev/disk/by-label/nixos`
- nixos-enter: pass/fail
- Reboot to installed OS: pass/fail

## Commands

```bash
# After live boot — on cerberus (Bitwarden agent unlocked):
./scripts/recovery-verify.sh --host <dhcp-ip> --root LABEL=nixos --enter
```
