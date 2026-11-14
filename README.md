# nixos-config

NixOS and home-manager configuration for my workstations, laptops and the Dell
staging cluster. It is a [flake-parts](https://flake.parts) flake in the
*dendritic* style: every `.nix` file under `modules/` is a flake-parts module
(loaded by [import-tree](https://github.com/vic/import-tree)), and features are
composed through a registry of named modules rather than file paths.

## Hosts

| Host | What | Built by |
|---|---|---|
| `cerberus` | main workstation (Hyprland, NVIDIA, local LLM rig) | `modules/hosts/cerberus/` |
| `lacie`, `kali-vm` | portable/VM desktops | deploy-node table |
| `argus`, `94tl0m2`, `95qmom2` | Dell staging cluster (colmena) | deploy-node table |
| `7PZSZY2` | WSL agent on a Windows laptop | `modules/hosts/7PZSZY2/` |
| `installerIso` | recovery/installer ISO | `modules/hosts/installer-iso/` |
| `stage-edge`, `stage-db` | OCI aarch64 hosts (external flake) | `inputs.nebula-infra` |

## Layout

```
flake.nix                 inputs + a bare flake-parts mkFlake
modules/
  flake/                  flake-level glue: outputs, flake.lib (mkHost, …),
                          the packages overlay, formatter, checks, apps
  nixos/                  flake.modules.nixos.<name>    — NixOS features
  home/                   flake.modules.homeManager.<name> — home-manager features
  desktops/<desktop>/     both halves of a desktop: default.nix (HM) + nixos.nix
  hosts/                  one directory per host; default.nix builds the
                          deploy-node table (_deploy-nodes.nix) with mkHost
  services/, infra/, …    service modules (infra ones move to nebula-infra)
pkgs/<name>/package.nix   custom packages, exposed via overlays.default and
                          packages.<system>.<name>
scripts/                  standalone scripts; module-private scripts live next
                          to their module
docs/                     runbooks; docs/migration/ holds the restructure spec
```

Conventions:

- **Modules are registered, not imported by path.** A feature file declares
  `flake.modules.<class>.<name>`, and hosts list
  `inputs.self.modules.<class>.<name>`. Names are explicit camelCase and
  recorded in `docs/migration/registry.json`, which
  `checks.<system>.module-registry` enforces.
- **Private files start with `_`.** import-tree skips them, so a feature can
  split itself into `_part.nix` files or keep a `script.sh` beside it.
- **Custom home-manager options live under `my.*`** (e.g. `my.zed.enable`) and
  host facts under `host.*` (`modules/nixos/host-options.nix`).

## Usage

```sh
nix flake check                                   # formatting, registry, every host evaluates
nix build .#nixosConfigurations.cerberus.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#cerberus      # apply on cerberus
nix run nixpkgs#colmena -- apply --on <host>      # Dell cluster
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for the boot-path rules and the commit
conventions, [docs/infra/git-history.md](docs/infra/git-history.md) for
branches and mirrors, and
[docs/infra/workspace-compute-budget.md](docs/infra/workspace-compute-budget.md)
for cerberus's CPU/memory ceilings.

## OCI and team Git hosting

The ARM64 OCI hosts run NixOS and use Tailscale for administration. Forgejo is
live at [git.nebula-1.com](https://git.nebula-1.com), served from `stage-db`
through Cloudflare Tunnel.

- [OCI inventory and routing](https://git.nebula-1.com/nebula/infra/src/branch/main/docs/infra/oci-forgejo.md)
- [Forgejo deployment, signup, backups, and recovery](https://git.nebula-1.com/nebula/infra/src/branch/main/infra/forgejo/README.md)
- [Personal Forgejo repository and GitHub mirror](docs/infra/repository-mirroring.md)

OCI sources now live in [nebula/infra](https://git.nebula-1.com/nebula/infra).
This flake preserves the stage host outputs as aliases. Instance-wide CI runs
on the dedicated OCI k3s node owned by that repo. Remaining workstation platform
services are still local; this is the OCI portion of M-602b.
