# CineMaya (Lumen) release pipeline
#
# Releases cut a version tag from git, pin it in `infra/lumen/version.nix`,
# and deploy to stage-edge. The app stays tailnet-only until the Cloudflare
# Tunnel connector is given a token; with a token it is also public at
# https://cinemaya.nebula-1.com. No public OCI ingress is ever opened.

## One-time setup (tunnel + DNS)

From the repository root, run `nix develop .#lumen`. The root flake lock pins
the tools.

Save these variables in `infra/lumen/.env.cloudflare` (ignored by Git), with
mode 0600: `TF_VAR_cloudflare_api_token`, `TF_VAR_cloudflare_account_id`, and
`TF_VAR_cloudflare_zone_id`. Use a token scoped to Tunnel Edit on the account
and DNS Edit / Zone Read on the nebula-1.com zone (same scopes as the Forgejo
tunnel in `infra/forgejo/README.md`).

```sh
set -a
source infra/lumen/.env.cloudflare
set +a
umask 077
tofu -chdir=infra/lumen init
tofu -chdir=infra/lumen plan -out=tfplan
tofu -chdir=infra/lumen apply tfplan
```

This creates tunnel `nebula-1-lumen`, routes `cinemaya.nebula-1.com` to it
(ingress `http://127.0.0.1:80`, i.e. nginx on stage-edge; everything else
404s), adds the proxied CNAME, and writes the connector token to
`infra/lumen/.env.tunnel` (mode 0600, ignored by Git). Inspect existing
tunnel/DNS resources before first apply; import matching resources into state
instead of creating duplicates. OpenTofu state and plans contain the tunnel
token: keep them private and backed up outside Git.

## Cutting a release

Upstream source is `System-Nebula/maya-unified`, directory `apps/lumen`.
Tags are `lumen-vX.Y.Z` on that repo's `main`.

1. Make sure `apps/lumen` is merged to upstream `main`. (As of the first
   pipeline commit it still sits on the unmerged branch `feat/lumen-app` —
   merge it first, then tag.)
2. Tag: `git tag lumen-v0.1.0 <main-sha> && git push origin lumen-v0.1.0`.
3. In this repo, edit `infra/lumen/version.nix`: set `version` to the tag
   (without prefix, e.g. `0.1.0`) and `rev` to the tagged commit SHA.
4. Re-derive the three hashes — set each to `lib.fakeHash`, build, and paste
   the real hashes Nix reports (never hand-write hashes):
   `srcHash`, `webNpmDepsHash`, `labNpmDepsHash`.
5. Commit: `feat(lumen): release 0.1.0`.

## Deploying a release

```sh
infra/lumen/deploy.sh
```

The script ships `.env.tunnel` to `/etc/lumen/.env.tunnel` (root-only,
atomic rename), dry-activates the new generation (built on the ARM host),
arms a 15-minute rollback timer, switches, then restarts `lumen-lab` and
starts `lumen-tunnel`. To rebuild without touching the token:

```sh
infra/lumen/deploy.sh --prepare
```

## Verification

- Tailnet: `curl http://stage-edge/` returns the CineMaya HTML shell.
- API/key: `curl 'http://stage-edge/api/search?q=dune'` returns TMDB JSON.
- Public: `curl https://cinemaya.nebula-1.com/` returns the same shell.
- Units: `systemctl is-active lumen-lab lumen-tunnel` → `active`.
- Posture: backend still binds `127.0.0.1:3847`; port 80 still
  `tailscale0`-only; the tunnel only dials out.

## Configuration ownership

| Concern | Source |
| --- | --- |
| Release pin (version + rev + hashes) | `infra/lumen/version.nix` |
| npm packaging from the pin | `modules/_features/overlays/lumen.nix` |
| Backend + tunnel connector units | `modules/services/lumen.nix` |
| stage-edge vhost + tunnel enablement | `modules/hosts/stage-edge/configuration.nix` |
| Tunnel, DNS, token output | `infra/lumen/main.tf` |
| Deploy + rollback procedure | `infra/lumen/deploy.sh` |
