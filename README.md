# nix

[![ci](https://github.com/MylesLandais/nix/actions/workflows/check.yml/badge.svg?branch=main)](https://github.com/MylesLandais/nix/actions/workflows/check.yml)

NixOS and Home Manager configuration for **cerberus**, my workstation. It is a
[flake-parts](https://flake.parts) flake in the *dendritic* style: every `.nix`
file under `modules/` is a flake-parts module (loaded by
[import-tree](https://github.com/vic/import-tree)), and features are composed
from a registry of named modules rather than imported by path.

## Cerberus

| | |
|---|---|
| Hardware | AMD Ryzen 5 5600X, NVIDIA RTX 3090 Ti, two monitors |
| Kernel | CachyOS kernel via [chaotic-nyx](https://github.com/chaotic-cx/nyx), nixos-unstable |
| Session | Hyprland (Lua config), [Noctalia](https://github.com/noctalia-dev/noctalia-shell) bar, SDDM |
| Theme | Stylix with Kanagawa Dragon, applied to GTK, Qt, terminals, editors and Hyprland's own tools |
| Shell | fish + starship, Ghostty and Kitty, zed, tmux / herdr |
| Other | Sunshine game streaming, Steam/Proton and Wine games, a local LLM router, agenix secrets |

## Layout

```
flake.nix                 inputs and a bare flake-parts mkFlake
modules/
  flake/                  flake-level glue: host builders, packages overlay,
                          formatter, checks, dev shell
  aspects/<domain>/       reusable NixOS and Home Manager features
  roles/                  compositions of several aspects
  hosts/cerberus/         machine facts and the host's wiring
  nixos/                  the GPU unlock module and its patches
pkgs/<name>/package.nix   custom packages (overlays.default, packages.<system>.<name>)
scripts/                  standalone tools; scripts/ci/ holds the CI checks
docs/                     runbooks; docs/layout/ holds the enforced module registry
secrets/                  agenix-encrypted secrets
```

Conventions:

- **Modules are registered, not imported by path.** A feature file declares
  `flake.modules.<class>.<name>`, and the host lists
  `inputs.self.modules.<class>.<name>`. Every name is recorded in
  `docs/layout/registry.json`, which `checks.<system>.module-registry` enforces.
- **Private helpers and data** sit behind an underscore-prefixed path, with a
  one-line comment naming their caller (`scripts/ci/check-layout.py` checks this).
- **Options:** host facts live under `host.*`
  (`modules/aspects/hosts/host-options.nix`), Home Manager options under `my.*`.

## Usage

```sh
nix develop                                       # treefmt, statix, deadnix, agenix
nix flake check                                   # formatting, registry, cerberus evaluates
nix build .#nixosConfigurations.cerberus.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#cerberus
```

`nix fmt` formats the tree. Custom packages build on their own with
`nix build .#<name>`; `pkgs/chatgpt-linux/update.sh` bumps the one vendor
download that only has a mutable URL.

## CI and binary cache

GitHub Actions (`.github/workflows/check.yml`) runs on the free hosted runners:

- **lint**: the layout checker, unit tests, nixfmt, deadnix and statix.
- **eval**: `nix flake check --no-build` and the cerberus derivation.
- **build** (pushes to `dev`/`main`, plus a weekly run): builds the custom
  packages and the full cerberus closure against the same upstream caches the
  machine uses, then pushes what it had to build to
  [`cerberus-nix.cachix.org`](https://cerberus-nix.cachix.org). Cerberus
  substitutes from that cache, so a rebuild downloads instead of compiling.

## Repository

Forgejo (`git.nebula-1.com/warbee/nix`) is the source of truth, and this GitHub
repository is its push mirror. `dev` is the working branch, and `main` is the
last release that ran on cerberus. Releases are tagged `vYYYY.MM.DD`, and the
newest dev snapshot is tagged `nightly/YYYY.MM.DD`. See
[docs/infra/repository.md](docs/infra/repository.md).

Retired hosts (the Dell cluster, laptops, the WSL agent, the installer ISO and
the OCI aliases) are preserved at tag `archive/multi-host-2026-11`. The Windows
provisioning kit moved to its own repository, `win`.

## Further reading

- [CONTRIBUTING.md](CONTRIBUTING.md): boot-path rules, service restart limits,
  cache policy.
- [docs/infra/README.md](docs/infra/README.md): local developer services on cerberus.
- [docs/infra/workspace-compute-budget.md](docs/infra/workspace-compute-budget.md):
  CPU and memory ceilings for background work.
- [docs/gaming/starcraft-remastered.md](docs/gaming/starcraft-remastered.md).

## Credits

Structure follows the dendritic pattern from
[mightyiam/dendritic](https://github.com/mightyiam/dendritic). The repository
began as a fork of [FKouhai/nix-dots](https://github.com/FKouhai/nix-dots), and
the Kanagawa palette is by [rebelot](https://github.com/rebelot/kanagawa.nvim).
