# NixOS repository mirroring

This is a personal configuration repository. Forgejo is the writable source of
truth and GitHub is the public mirror.

| Role | Repository |
| --- | --- |
| Canonical Forgejo (`origin`) | https://git.nebula-1.com/warbee/nix |
| Public GitHub mirror (`github`) | https://github.com/MylesLandais/nix |

Push and review changes in Forgejo. Configure `warbee/nix` as a regular
repository (not a pull mirror), enable its outbound GitHub mirror, and use
**Settings → Repository → Mirror Settings → Synchronize Now** after changing
the mirror configuration.

## Local checkout

```sh
git remote set-url origin https://git.nebula-1.com/warbee/nix.git
git remote set-url github https://github.com/MylesLandais/nix.git
git push origin dev
git push origin main
```

The Forgejo remote is intentionally named `origin`; the GitHub remote is a
verification and recovery target, not an independent source of truth. Use your
own Forgejo access token for HTTPS or your registered SSH key through the
tailnet Git endpoint. Tailscale users can instead use
`ssh://git@100.123.116.99:2222/warbee/nix.git` after adding their public key to
Forgejo and verifying the server fingerprint in the deployment runbook.

## Verify and recover synchronization

After the mirror sync completes, compare the full `main` and `dev` SHAs shown
by GitHub and Forgejo. A successful local push alone does not prove mirror
convergence. If the mirror falls behind, inspect the last mirror update and
error in its settings, correct outbound access to GitHub, then request
synchronization.

Never force-push to reconcile unexplained divergence. Preserve any
GitHub-only commit in Forgejo before retrying. This setup replicates Git
branches and tags; it does not replicate issues, pull requests, Actions
secrets, release assets, or Forgejo users and permissions. LFS is not enabled
for this mirror. Forgejo's database and file backups remain necessary.

API reference for the running instance:
https://git.nebula-1.com/api/swagger
