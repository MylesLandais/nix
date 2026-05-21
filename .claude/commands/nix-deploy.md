---
description: Deploy a NixOS configuration to a remote machine using Colmena
allowed-tools: Bash
---

# nix-deploy: Remote Deployment

Deploy the flake's NixOS configuration to remote hosts using Colmena. Only deploy after local validation passes.

## Prerequisites

- The target host is defined in the Colmena hive configuration (`hive.nix` or `flake.colmena`)
- SSH key access is configured and the target is reachable
- `colmena` is available in the dev shell or via `nix run nixpkgs#colmena`
- Local validation has passed for the target host:
  ```bash
  nix build .#nixosConfigurations.<host>.config.system.build.toplevel
  ```

## Why Colmena (not deploy-rs)

deploy-rs uses `rnix` 0.8 to discover nodes from `flake.nix`. It cannot trace through `flake-parts` + `import-tree`. Colmena has native flake support and does not have this limitation. Colmena 0.4 is in nixpkgs — no extra flake input needed.

## Execution

Deploy a single host:

```bash
cd ~/.config/nixos
colmena apply --on <hostname>
```

With build-only (dry-run):

```bash
colmena build --on <hostname>
```

Deploy all configured nodes:

```bash
colmena apply
```

Deploy a subset (e.g. staging group):

```bash
colmena apply --on @staging
```

## What Happens

1. The closure for each target `nixosConfigurations.<host>` is built (or fetched from cache)
2. Colmena copies the closure to the target via SSH/nix copy
3. The target runs `switch-to-configuration` to activate the new generation
4. On success, the target is running the new configuration

## Success

Report the host and generation. Verify with:

```bash
ssh <hostname> 'nixos-rebuild list-generations | head -3'
```

## Failure

Common failures:
- SSH unreachable: verify `hostname` in hive config and network connectivity
- Permission denied: verify key is in target's `~/.ssh/authorized_keys`
- Sudo password prompt: add NOPASSWD sudo rule or use `user = "root"` in node config
- Build failure: run `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` locally to isolate

If deployment leaves the target in a bad state, roll back on the target:

```bash
ssh <hostname> 'sudo nixos-rebuild switch --rollback'
```

## Supported Hosts

Current deploy nodes are defined in the Colmena hive. Only deploy to hosts explicitly configured there. Do not invent hostnames. If a new host needs deployment support, add it to the hive first, validate, then deploy.
