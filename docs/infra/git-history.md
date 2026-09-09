# Git history and collaboration

Forgejo is canonical: https://git.nebula-1.com/warbee/nix
GitHub mirror: https://github.com/MylesLandais/nix
This is a personal configuration repository owned by `warbee`; it is not a
shared `nebula` organization configuration. GitHub remains public, including
mirrored dev and historical branches.

## Branches

- `dev` is the default working tree. Branch from it for new work and send reviews to Forgejo.
- `stable` is the former GitHub `main` baseline. Promote tested work through reviewed merge commits; it is not an automatic deployment branch.
- Imported feature branches retain their names. `archive/github/*`, `archive/local/*`, and (for Tint) `archive/standalone/*` preserve the exact source tips observed during migration. They are historical snapshots, not additional supported source trees.
- Original commits, authors, merges, and tags are retained. Divergent same-name tags use `archive/<source>/...` names.

The dev tree includes the current workstation and service source, deployed Forgejo configuration, and the reconciled GitHub WSL and Windows-host history. NixOS and OpenTofu remain the sources of truth for systems and OCI/network infrastructure. Publishing source does not deploy it.

## Context and recovery

The 2026-09-07 migration imported GitHub PRs, discussions on those PRs, labels, milestones, releases and wiki content where supported. Original GitHub URLs remain useful context; new issues and reviews belong in Forgejo. Git mirroring replicates branches and tags, not subsequent issue/PR activity.

The administrators retain a private migration archive with source-ref inventories, Git bundles, working patches, untracked files, stash recovery, PR review/timeline exports, CI metadata and validation logs. Raw recovery material and credentials are not part of the public mirror.

## Cloning and synchronization

```sh
git clone --recurse-submodules https://git.nebula-1.com/warbee/nix.git
```

Use your own Forgejo access token for HTTPS or your registered SSH key through the tailnet Git endpoint. Local `origin` points to the personal Forgejo repository and `github` points to the public mirror. Push and merge in Forgejo. Configure the Forgejo repository mirror to update GitHub after pushes, then check Settings → Repository → Mirror Settings for the last result and use Synchronize Now to retry.

Do not independently push to GitHub: its refs are replicas and can be
overwritten by synchronization. Preserve an unexpected GitHub-only commit in
Forgejo before retrying a mirror.

## Validation baseline

Cerberus builds successfully and the broad flake evaluation passes. OpenTofu
formatting and validation pass. ARM stage validation is recorded separately in
the migration report.
