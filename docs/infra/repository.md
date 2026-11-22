# Repository, branches and mirroring

| Role | Repository |
| --- | --- |
| Source of truth (`origin`) | https://git.nebula-1.com/warbee/nix |
| Public mirror (`github`) | https://github.com/MylesLandais/nix |

Push to Forgejo only. `warbee/nix` push-mirrors every branch and tag to GitHub
with pruning, so anything pushed straight to GitHub is overwritten on the next
sync. Exactly one Forgejo repository may mirror to GitHub. When two did, they
force-pushed each other's refs every sync interval, and each flip started a CI
run.

## Branches and tags

- `dev` is the working branch. Work lands here, by direct commit or by merging a
  short-lived branch.
- `main` is the release: the commit cerberus last switched to after it passed
  CI. Fast-forward it from `dev`, then tag it `vYYYY.MM.DD`.
- `nightly/YYYY.MM.DD` tags the `dev` snapshot cerberus is running between
  releases. Keep only the newest one.
- `archive/multi-host-2026-11` preserves the tree from before it was reduced to
  cerberus (Dell cluster, laptops, WSL agent, installer ISO, OCI aliases, Windows
  kit).

Delete merged branches and their worktrees once they land.

## Local checkout

```sh
git clone https://git.nebula-1.com/warbee/nix.git ~/.config/nixos
git -C ~/.config/nixos remote add github https://github.com/MylesLandais/nix.git
```

`github` is for checking that the mirror has converged. Don't push to it.

## Verify synchronization

After a push, compare the `dev` and `main` SHAs on both sides:

```sh
git ls-remote origin refs/heads/dev refs/heads/main
git ls-remote github refs/heads/dev refs/heads/main
gh api repos/MylesLandais/nix/activity -q '.[0:5][]|.timestamp+" "+.ref+" "+.activity_type'
```

A `force_push` in the activity log that you didn't make means another mirror is
pushing. If the mirror falls behind, check the last error under **Settings →
Repository → Mirror Settings** in Forgejo and use **Synchronize Now**. The
mirror replicates Git refs only: issues, pull requests, Actions secrets and
release assets are not copied.
