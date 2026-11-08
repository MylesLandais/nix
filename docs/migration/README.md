# Dendritic migration

This directory holds the executable spec for the migration to a fully dendritic
layout and the split into three repos: nixos-config, windows-kit and
nebula-infra.

- `tasks.yaml`: task contracts, in dependency order
- `registry.json`: expected module registry (enforced from M-003 on)
- `baseline/`: snapshots of all hosts at tag `migration/baseline`
- `evidence/<task>.json`: verification record per integrated task
- `frozen.txt`: paths leaving the repo in Phase 6; not editable before then
- `volatile.txt`: known per-commit noise, each entry with a reason

## Harness

```
nix run .#migration -- capture   [--rev REV] [--hosts a,b|all]
nix run .#migration -- verify    --task ID [--rev REV] [--against REV] [--hosts …] [--write-evidence]
nix run .#migration -- audit     [--rev REV]
nix run .#migration -- inventory [--rev REV]
```

Snapshots are always taken from the committed tree at an exact revision
(`git+file://…?rev=<sha>`). The harness checks that the evaluated flake reports
that same revision. With uncommitted changes, it refuses to run against a bare
`HEAD`. Snapshots are cached in `.migration/cache/<harness-id>/<sha>/`
(gitignored), keyed by the harness version as well as the commit.

| Layer | What | Source |
|---|---|---|
| A, structural | flake output tree; module registry (`modules.*`, `nixosModules`, `homeManagerModules`); path-based imports (`"${self}/modules/…"`, `../`) from `git grep` | `snapshot.nix` `.flake.A`, git |
| B, derivations | per-host `toplevel.drvPath` and HM `activationPackage.drvPath`; `packages`/`devShells` drvPaths | `.host <h>`.B, `.flake.B` |
| C, configuration | units (system and user: enable, wantedBy, text hash), activation scripts, `/etc` sources, package identities per profile, firewall, networking, users and groups, `nix.settings`, nixpkgs config, filesystems, swap, session, `programs.*`/`services.*` enable flags, `host.*`, `wsl.*`, and for each HM user: files, packages, session variables, activation, programs/services, user units, window manager settings | `.host <h>`.C |

Identical drvPaths are strong evidence that the build is unchanged. They don't
prove the configuration is unchanged, which is why layer C exists. Layer C
normalizes store hashes (`/nix/store/HASH-…`): a store path that changes only
because something upstream was rebuilt is not a configuration change.

### Content equivalence

Moving a module into the registry nests it deeper in the module tree. That
changes the order in which list definitions merge (for example the order of
`home.packages`), and so the drvPath, without changing what gets built. When a
host's drv changes and layer C shows no change, `verify` proves equivalence
(`scripts/migration/drv-equiv.sh`):

1. Pair the differing derivations and input sources by name, recursively.
2. Map each pair's outputs to a shared placeholder on both sides.
3. A pair that is identical under that map differs only through its inputs.
   Every other pair is a root: build it, old and new, and compare the outputs
   file for file under the same map.

The proof fails if any input is unpaired, if a build would fetch more than
`MIGRATION_MAX_FETCH_MIB` (default 2048), or if any root's outputs differ.
`order-insensitive.txt` lists the few files whose token order carries no
meaning; each entry has a reason. Self-test 7 checks that a hidden content
change (same package name and version) is rejected.

## Policies

| Policy | A | B | C |
|---|---|---|---|
| `pure_refactor` | registry changes only as declared in `registry:` | identical, or provably content-equivalent | no difference |
| `contract_change` | outputs may change only where they match `contract:` globs | identical, except new outputs matching `contract:` | no difference |
| `behavior_change` | as for `pure_refactor` | may change on hosts whose C changes explain it, or that `allowed_changes` lists as `<host>:B/*` | each changed path must match an `allowed_changes` glob `<host>:<path>` |
| `repo_move` | Phase 6; source-provenance differences only, judged by per-file content hashes and nix-diff (added to the harness in Phase 6) | | |

Under `pure_refactor`, any difference means **stop and investigate**. Never
widen a policy, edit the baseline, or add to `volatile.txt` to get a task
through.

`allowed_changes` entries are bash globs over the flattened snapshot paths
(for example `cerberus:etc/nix/nix.conf/*` or `cerberus:homeManager/warby/files/*noctalia*`).
Use `flake:<path>` for flake-level layer B.

## Task contract

```yaml
- id: M-214
  title: Convert shelltools/atuin to homeManager.atuin
  phase: 2
  depends_on: [M-104]
  policy: pure_refactor
  hosts: [cerberus, lacie, kali-vm]       # verified per commit; checkpoints cover all
  touches: [modules/_features/shelltools/atuin*, modules/home/atuin.nix, modules/_home.nix]
  resources:
    reads:  [registry.homeManager, host.cerberus, host.lacie, host.kali-vm]
    writes: [module.homeManager.atuin, registry.homeManager, option.my.atuin]
  registry: {add: [homeManager.atuin], remove: []}
  contract: []          # contract_change only: output path globs allowed to change
  allowed_changes: []   # behavior_change only
  allow_frozen: false
  path_imports_allow: 0 # declared, justified increase in path-based imports
  done_when: no path import of atuin remains; layer B identical; layer C no diff
```

Resource kinds: `module.<class>.<name>`, `registry.<class>`, `option.<path>`,
`overlay`, `host.<name>`, `flake.inputs`, `flake.outputs`.

## Execution rules

- **Parallel preparation.** Workers may prepare tasks in parallel worktrees
  only when both hold:
  - their `touches` sets don't overlap;
  - no task `writes` a resource another task `reads` or `writes`.
- **Serial integration.** The integration agent merges tasks one at a time:
  1. Rebase the task onto integration HEAD.
  2. Commit the task.
  3. Run `verify --task <id> --write-evidence` against that commit.
  4. Commit the evidence as `chore(migration): evidence <id>`.

  Evidence from a worker's worktree is preliminary and is never committed.
- **Rollback.** Each task is one commit (plus its evidence commit), so a task
  is rolled back by reverting its commit. Each phase ends at a tag
  `migration/phase-N` after `verify --hosts all` against the previous
  checkpoint.
- **Final audit.** `audit` compares HEAD with `migration/baseline`. Every
  difference must be recorded in some evidence file.
- **Human approval** is needed only for:
  - credential rotation
  - creating or pushing the new remotes
  - the wallpaper choice (M-505)
  - `nixos-rebuild switch`
  - cluster deploys
  - merging to `dev`

## Module naming

- Module names are explicit literals in camelCase, never derived from file
  paths. Moving a file never renames a module.
- Existing public names are kept.
- Hosts are named `nixos.host<Name>`. Hardware modules are `<host>Hardware`.
- A rename is declared in the task's `registry:` (remove the old name, add the
  new one) and recorded in `registry.json` in the same commit.
- `checks.<system>.module-registry` (`modules/flake/module-registry.nix`) fails
  `nix flake check` when the registry and `registry.json` disagree.
