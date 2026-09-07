# NixOS repository mirroring

GitHub is the writable source for this repository. Forgejo keeps a private
pull mirror, updated hourly, so copying Git history does not depend on the
workstation being online.

| Role | Repository |
| --- | --- |
| Source (`origin`) | https://github.com/MylesLandais/nix |
| Pull mirror (`forgejo`) | https://git.nebula-1.com/warbee/nix |

Commit and push to `origin/main`. The mirror fetches branches and tags from
the public GitHub source without a GitHub credential. Its owner can request
an immediate sync in the Forgejo repository settings. The mirror is read-only
for Git pushes; independent Forgejo repositories can still be writable.

## Local checkout

```sh
git remote set-url origin https://github.com/MylesLandais/nix.git
git config credential.https://github.com.helper ''
git config --add credential.https://github.com.helper '!gh auth git-credential'
git remote add forgejo https://git.nebula-1.com/warbee/nix.git
git push origin main
```

The GitHub helper uses the existing `gh` login; no token belongs in a remote URL.
When `forgejo` already exists, use `git remote set-url forgejo URL`. Fetching
the private mirror over HTTPS requires a Forgejo personal access token.
Tailscale users can instead use
`ssh://git@100.123.116.99:2222/warbee/nix.git` after adding their public key to
Forgejo and verifying the server fingerprint in the deployment runbook.

## Verify and recover synchronization

After the mirror sync completes, compare the full `main` SHA shown by GitHub
and Forgejo. A successful local push alone does not prove mirror convergence.
If the mirror falls behind, inspect the last mirror update and error in its
settings, correct outbound access to GitHub, then request synchronization.

To change the source of truth, first pause automatic pulling and explicitly
convert the Forgejo repository into a regular repository before accepting
independent commits there. Never force-push to reconcile unexplained divergence.

This setup replicates Git branches and tags. It does not replicate GitHub
issues, pull requests, Actions secrets, release assets, or Forgejo users and
permissions. LFS is not enabled for this mirror. Forgejo's database and file
backups remain necessary; current backups are local to stage-db, with off-host
backup work still pending.

API reference for the running instance:
https://git.nebula-1.com/api/swagger
(`POST /repos/migrate`, `POST /repos/{owner}/{repo}/mirror-sync`).
