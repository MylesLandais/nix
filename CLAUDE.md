# NixOS Configuration Style Guide

This document extends the global Claude Code rules with Nix-specific guidance.

## Nix Development Workflow

All changes follow this sequence: Edit, Validate with /nix-check, Commit, Apply with /nix-switch for local Cerberus changes, or Deploy with /nix-deploy for remote hosts.

Do not skip /nix-check. Do not commit unvalidated changes. Do not apply changes to live system without validation. Do not deploy to remote hosts without first building the target configuration locally.

### Before /nix-switch: show the effect

A switch restarts every unit whose file changed, and it applies everything
dirty in the tree, not only your edit. Before asking for confirmation:

1. `git status --short`. List the other dirty files the switch will also apply
   (flake.lock bumps, other agents' edits). Commit only your own files, by
   explicit path.
2. `nixos-rebuild build --flake .#cerberus` (no sudo, no activation). The flake
   output is `cerberus`; `$(hostname)` is `cerberus-nix`, and that name doesn't
   work.
3. List the changed units: compare each `result/etc/systemd/system/*.service`
   against `/run/current-system/etc/systemd/system/` (`cmp` on the resolved
   paths). For each service you touched, show the `ExecStart` diff.
4. Check whether anything is using the services that will restart. SeaweedFS
   is used by the crawler and booru containers and by the music worker
   (`nebula-library-reconcile.service`). Postgres runs in Docker and isn't
   restarted by a switch.
5. Remove the `result` symlink afterwards.

### Sessions started outside this repo

The `/nix-*` commands and the permissions in `.claude/settings.local.json`
(git commit, `sudo nixos-rebuild`) load only in sessions started in
`~/.config/nixos`. A session started elsewhere (for example `~/Workspace`) can
edit and build here. Its classifier may still refuse the commit or the switch.
When that happens, don't work around it: give the user the exact command
(`sudo nixos-rebuild switch --flake ~/.config/nixos#cerberus --show-trace -L`)
or suggest running `/nix-switch` from a session started here. `nixos-rebuild`
is NOPASSWD for `warby`.

## Where to Make Changes

Every `.nix` file under `modules/` is a flake-parts module loaded by import-tree, except files and directories whose name starts with `_` (private to the module next to them). Features are registry modules, never imported by path:

- Reusable features live under `modules/aspects/<domain>/`. Register their NixOS and Home Manager contributions under `flake.modules.nixos.<name>` and `flake.modules.homeManager.<name>`. The shared Home Manager base imports the common features. Keep host options under `host.*` and user options under `my.*`.
- Put reusable compositions in `modules/roles/`. Keep machine facts and the wiring that instantiates a machine in `modules/hosts/<host>/`. Use underscore Nix paths for private helpers and data, and name the caller or purpose in a one-line comment.
- New or renamed module: update `docs/migration/registry.json` in the same commit (`checks.<system>.module-registry` enforces it).

Cerberus keeps its DNS, browser and model-service settings in `adguard.nix`, `chromium.nix` and `llm-router.nix` beside the host configuration. Its private monitor table is `_desktop-layout.nix`.

Host composition: deploy-node hosts are entries in `modules/hosts/_deploy-nodes.nix` (built by `modules/hosts/default.nix` and read by `colmena.nix`); cerberus and 7PZSZY2 call `config.nodeBuilders.mkHost` in their own `default.nix`.

Custom packages: `pkgs/<name>/package.nix`, picked up automatically by `overlays.default` and `packages.<system>.<name>` (`modules/flake/packages.nix`). Long scripts belong in a file next to their module, read with `builtins.readFile`, not inline in Nix strings.

Anything that adds a boot-time service, a `home.activation` script, or a dependency on `docker.service` must follow CONTRIBUTING.md §9 (boot path): Docker is socket-activated and must never be pulled in at boot, and HM activation blocks the login screen.

Validate with `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` or `nix flake check`. Apply locally on Cerberus with `/nix-switch` (`nixos-rebuild switch --flake …#cerberus`). Do not run `home-manager switch` alone.

## Common Procedures

### Repetitive System Maintenance

Use this pattern for flake input updates, package bumps, lockfile refreshes, and other small maintenance tasks.

Start with `git status --short` and identify any existing dirty files. Keep the change atomic: do not mix unrelated cleanup, formatting, or opportunistic fixes. If the user gives an exact version or tag, pin that exact version rather than updating to latest.

For flake input updates, inspect the current input in `flake.nix`, update only that input, then refresh the lockfile from the flake directory. Prefer `nix flake update input-name`; older invocations such as `nix flake lock --flake ...` may not be supported by the installed Nix.

Validate narrowly first. For Cerberus-impacting changes, run `nix build .#nixosConfigurations.cerberus.config.system.build.toplevel`. Use `nix flake check` when practical, but if it fails on an unrelated host option, report that blocker and validate the affected host directly.

Clean up generated repo-local artifacts such as the `result` symlink after builds. Finish with `git diff --check` and `git status --short`, and report the exact files changed plus validation results.

### Add a System Package

Edit `modules/aspects/packages/env-packages.nix` (shared desktop) or the host’s `configuration.nix` for host-only packages. Add the package name. Run /nix-check. If error "attribute missing", the package doesn't exist in nixpkgs; search with `nix search nixpkgs package-name`. Commit with `chore(packages): add package-name`. Run /nix-switch.

### Add User Program or Dotfile

Edit `modules/aspects/desktop/base/_packages.nix` (package list), `modules/aspects/desktop/base/default.nix`, or the feature under `modules/aspects/`. Find `home.packages` or create a `home.file` entry. Use proper XDG paths for config files. Run /nix-check. If home-manager syntax error, the error message shows file and line number. Commit appropriately. Run /nix-switch.

Important: Do NOT run home-manager switch alone. Always use nixos-rebuild switch which handles both system and home-manager.

### Update Git Configuration

Edit `modules/aspects/development/devtooling/git.nix`. Find `programs.git.settings` and add or modify the setting. Run /nix-check. Commit with `chore(git): add or update setting_name`. Run /nix-switch.

Git config at `~/.config/git/config` is read-only (symlink to `/nix/store`). All changes must be in that module. Verify after rebuild with `git config --global key_name`.

### Add Passwordless Sudo Rule

Edit `modules/aspects/system/security.nix` (shared) or the host’s `configuration.nix`. Find `security.sudo.extraRules`. Add a new rule with command path and NOPASSWD. Use `/run/current-system/sw/bin/command` for paths (not `${pkgs.command}`). Run /nix-check. Commit with `chore(sudo): add NOPASSWD for command_name`. Run /nix-switch.

### Fix Build Errors After /nix-check

Read error message and note file path and line number. Common errors: "attribute X missing" means typo or package doesn't exist. "syntax error" means Nix syntax issue, check brackets and semicolons. "infinite recursion" means circular dependency. "Read-only file system" means trying to edit `/nix/store`; change the `.nix` source instead. Fix the issue. Run /nix-check again. Repeat until all phases pass.

### Handle Home-Manager Configuration Not Applying

Changes to Home Manager or desktop aspects should appear in `~/.config` after rebuild. If not: Verify rebuild ran by checking the target file. If the file is old, rebuild didn't apply. Cause is usually running `home-manager switch` instead of `nixos-rebuild switch`. Run: `sudo nixos-rebuild switch --flake ~/.config/nixos#cerberus`. Wait for completion. Check file again. If still missing, check the module is imported in `modules/aspects/desktop/base/default.nix` (or the host’s `home.nix`) and registered in `docs/migration/registry.json`. If still failing, run /nix-check for validation errors.

### Shell Not Seeing Changes

Changes to environment, PATH, or other shell variables need shell restart. Verify changes applied by checking config file or running git config --global credential.helper. Restart current shell with exec fish (or bash). Test command again. If still old values, reboot: sudo reboot.

Opening a new terminal window does NOT reload environment. Must restart the current shell with exec.

## Remote Deployment

Remote hosts are deployed with **Colmena**, not deploy-rs. Node definitions live in `colmena.nix`; each node’s system closure comes from the matching `flake.nixosConfigurations.<name>`.

Deploy after validating the target locally:

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
nix run nixpkgs#colmena -- apply --on <host>
```

See [docs/cluster/colmena.md](docs/cluster/colmena.md) and [.claude/commands/nix-deploy.md](.claude/commands/nix-deploy.md) for topology, SSH, and troubleshooting.

Local Cerberus changes use `/nix-switch` instead of Colmena.

### Requirements on target

- NixOS with flakes enabled
- SSH key access for the deploy user
- Passwordless sudo for the Colmena profile user (or deploy as root)
- `x86_64-linux` for current cluster nodes

### Deploy troubleshooting

- SSH: verify hostname and keys in `modules/aspects/identity/ssh-keys.nix` / target `authorized_keys`
- Sudo prompts: add NOPASSWD or use root in `colmena.nix`
- Build failures: reproduce with `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
- Rollback on target: `sudo nixos-rebuild switch --rollback`

## Task Completion Pattern

After completing work:

Report completion status plainly. Include work summary. Verify changes are tracked in git. Report files modified or deployed. Confirm validation and rebuilds passed.

Verification examples: Git (commit hash, staging status). Nix (validation passed, rebuild succeeded, symlinks confirmed). System (functionality tested, services running).

## Resources

Nix Manual: https://nixos.org/manual/nix/stable/
NixOS Manual: https://nixos.org/manual/nixos/stable/
Home Manager Manual: https://home-manager-options.extranix.com/
NixOS & Flakes Book: https://nixos-and-flakes.thiscute.world/
Statix: https://github.com/nix-community/statix
Hyprland: https://wiki.hyprland.org/
Fish Shell: https://fishshell.com/docs/current/
Conventional Commits: https://www.conventionalcommits.org/

When troubleshooting: Check NixOS Manual for module options. Check nixpkgs source for package names. Search NixOS Discourse or GitHub issues for build errors. Check official docs for language-specific config (fish, hyprland).
