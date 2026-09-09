# Git history and collaboration

Forgejo is canonical: https://git.nebula-1.com/nebula/nixos
GitHub mirror: https://github.com/MylesLandais/nix
The private nebula organization is owned by warbee and lain.
GitHub remains public, including mirrored dev and historical branches.

## Branches

- `dev` is the complete working tree. It contains Cerberus, the other host configurations, and the deployment/recovery tooling. Branch from it for new work and send reviews to Forgejo.
- `main` is the Cerberus release tree. It intentionally contains only the Cerberus configuration and the shared modules needed to build and operate it.
- `stable` points at the current Cerberus release commit. Promote tested work through reviewed merge commits; it is not an automatic deployment branch.
- Imported feature branches retain their names. `archive/github/*`, `archive/local/*`, and (for Tint) `archive/standalone/*` preserve the exact source tips observed during migration. They are historical snapshots, not additional supported source trees.
- Original commits, authors, merges, and tags are retained. Divergent same-name tags use `archive/<source>/...` names.

The dev tree includes the current workstation and service source, deployed Forgejo configuration, and the reconciled GitHub WSL and Windows-host history. The release branches intentionally omit those non-Cerberus host entrypoints; their source remains on `dev`. NixOS and OpenTofu remain the sources of truth for systems and OCI/network infrastructure. Publishing source does not deploy it.

## Context and recovery

The 2026-09-07 migration imported GitHub PRs, discussions on those PRs, labels, milestones, releases and wiki content where supported. Original GitHub URLs remain useful context; new issues and reviews belong in Forgejo. Git mirroring replicates branches and tags, not subsequent issue/PR activity.

The administrators retain a private migration archive with source-ref inventories, Git bundles, working patches, untracked files, stash recovery, PR review/timeline exports, CI metadata and validation logs. Raw recovery material and credentials are not part of the public mirror.

## Cloning and synchronization

```sh
git clone --recurse-submodules https://git.nebula-1.com/nebula/nixos.git
```

Use your own Forgejo access token for HTTPS or your registered SSH key through the tailnet Git endpoint. Local `origin` points to Forgejo and `github` retains the original GitHub URL. Push and merge in Forgejo. A repository-scoped SSH deploy key permits Forgejo to update GitHub after pushes, with an hourly retry. Check Settings → Repository → Mirror Settings for the last result and use Synchronize Now to retry.

Do not independently push to GitHub: its refs are replicas and can be overwritten by synchronization. Preserve an unexpected GitHub-only commit in Forgejo before retrying a mirror. Private repositories require explicit repository or organization membership.

## Validation baseline

Cerberus builds successfully. OpenTofu formatting and validation pass. Broad flake evaluation currently fails on the pre-existing installer use of the archived hyprpanel package; this is outside the migration changes. ARM stage validation is recorded separately in the migration report. No systems were activated by this migration.
