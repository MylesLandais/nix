# Colmena Hive

The cluster deploys via Colmena (0.4, from nixpkgs). Hive definition lives at `colmena.nix` at the repo root, grafted onto the flake outputs in `flake.nix`:

```nix
(flake-parts.lib.mkFlake { ... } { ... })
// {
  colmena = import ./colmena.nix { inherit inputs; };
}
```

flake-parts doesn't whitelist a `colmena` output, hence the merge after the call. All other outputs (`nixosConfigurations`, `homeManagerModules`, `packages`, `apps`) stay inside flake-parts.

## Why Colmena, not deploy-rs

`deploy-rs` uses `rnix` 0.8 which cannot trace through `flake-parts` + `import-tree` syntax. Colmena evaluates the flake directly and has no such issue.

## Tag taxonomy

Every node carries a small set of orthogonal tags. Hardware × tier × role:

- Hardware: `7050`, `3080`
- Tier:     `storage`, `compute`, `gateway`, `presentation`
- Role:     `data-core`, `media-pipeline`, `automation`, `postgres`, `postgres-replica`, `seaweedfs`, `traefik`, `observability`

Pick the smallest subset that explains the node. `95qmom2` is `7050 storage data-core postgres seaweedfs`.

## Common commands

```bash
nix run nixpkgs#colmena -- apply switch --on 95qmom2 --impure
nix run nixpkgs#colmena -- apply switch --on @data-core --impure
nix run nixpkgs#colmena -- apply switch --on '@7050,@storage' --impure
nix run nixpkgs#colmena -- build --on 95qmom2 --impure
nix run nixpkgs#colmena -- exec  --on 95qmom2 -- hostnamectl
```

`--impure` is needed while the working tree is dirty (the flake input `self` can't be locked then). Drop the flag once changes are committed.

## SSH and sudo

Colmena's `defaults` block sets `targetUser = "warby"`. The deploying user must have `~/.ssh/id_ed25519` loaded into `ssh-agent` (the agent is *required* — Colmena doesn't take `-i`). Targets must have NOPASSWD sudo for `warby` (handled by `security.sudo.wheelNeedsPassword = false` in `nixosModules.qmom2`).

Quick agent setup on cerberus:

```fish
eval (ssh-agent -c)
ssh-add ~/.ssh/id_ed25519
```

## Closure-identity caveat

Colmena evaluates with `lib.evalModules`, not `inputs.nixpkgs.lib.nixosSystem`. The resulting NixOS toplevel uses label `26.05pre-git` rather than the locked `26.05.20260505.<rev>` you get from `nix build .#nixosConfigurations.<name>.config.system.build.toplevel`. The closure content is otherwise identical — only the `nixos.label` string differs.

To make Colmena's closure carry the same nixpkgs source that `lib.nixosSystem` ships, `modules/features/nix-config.nix` explicitly sets:

```nix
nix.registry.nixpkgs.flake = inputs.nixpkgs;
nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
```

## Adding a node

For a second OptiPlex 7050 (media pipeline / storage), the on-ramp is:

1. Bring up the target with NixOS installed, ssh enabled, `warby` user, our keys in `authorized_keys`, NOPASSWD sudo.
2. On the target: `sudo nixos-generate-config` and capture `/etc/nixos/hardware-configuration.nix`.
3. In the repo, create `modules/hosts/<tag>/` containing:
   - `configuration.nix` — define `flake.nixosModules.<tag>` mirroring `nixosModules.qmom2`. Override hostname.
   - `hardware-configuration.nix` — wrap the generated file as `flake.nixosModules.<tag>Hardware`.
   - `default.nix` — define `flake.nixosConfigurations."<tag>"` with the module list (same shape as `95qmom2/default.nix`).
4. Add a node block to `colmena.nix`:

   ```nix
   "<tag>" = { lib, ... }: {
     deployment.targetHost = "<lan-or-tailnet-ip>";
     deployment.tags = [ "7050" "storage" "media-pipeline" "postgres-replica" "seaweedfs" ];
     imports = [
       inputs.self.nixosModules.<tag>
       inputs.self.nixosModules.<tag>Hardware
       inputs.self.nixosModules.<tag>Postgres
       inputs.self.nixosModules.<tag>Seaweedfs
       # ... and the same nix-config / fish-config / home-manager block
     ];
   };
   ```

5. `nix run nixpkgs#colmena -- build --on <tag> --impure` first. Investigate any drift before pushing.
6. `nix run nixpkgs#colmena -- apply switch --on <tag> --impure`.

### What's per-node vs. shared

Per-node:
- Hostname (in `nixosModules.<tag>`)
- Disk UUIDs (in `nixosModules.<tag>Hardware`)
- Tailscale IP hardcoded in `seaweedfs.nix` (`tailscaleIp` let-binding)
- `deployment.targetHost` and `deployment.tags`
- Postgres: replica nodes use a different module that configures streaming replication (TODO)

Shared (in `modules/features/` and pulled by every node):
- `nix-config.nix` — registry, nixPath, GC, substituters
- `fish-config.nix`
- Eventually role modules like `seaweedfs.nix` can be promoted to `modules/services/` once a second node exists

## Reference

- Colmena upstream: <https://colmena.cli.rs/>
- 95qmom2 specifics: `docs/cluster/95qmom2.md`
- Staging plan: `~/Vault/staging-cluster-nixos-plan.md`
