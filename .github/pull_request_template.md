<!-- Forgejo (git.nebula-1.com/warbee/nix) is the source of truth; GitHub is a read-only mirror. -->

## What and why

## Validation

- [ ] `nix flake check`
- [ ] `nix build .#nixosConfigurations.cerberus.config.system.build.toplevel`
- [ ] Changed services and their `ExecStart` diff reviewed (see CLAUDE.md, "Before /nix-switch")
- [ ] New or renamed modules recorded in `docs/layout/registry.json`
