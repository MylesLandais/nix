# Recovery test — 95qmom2 — pending (after 94tl0m2)

Repeat checklist from [recovery-hardware-qa.md](recovery-hardware-qa.md) after 94tl0m2 passes.

- Expected root: `/dev/sda3` or `by-uuid/89395068-a5be-4b51-af6d-856a77ba5fa2`
- LAN: `192.168.0.49` / Tailscale `dell-potato`
- **Do not run `nix-install`**

```bash
./scripts/recovery-verify.sh --host 192.168.0.49 --root /dev/sda3 --enter
```
