# Forgejo on stage-db

Forgejo runs on NixOS ARM64 at `100.123.116.99`. HTTPS uses Cloudflare Tunnel
at `https://git.nebula-1.com`; Git SSH uses Tailscale port 2222. Signup is public,
but an administrator must activate each account. Private repositories require
separate membership. SMTP is not configured, so there are no activation or
password-reset emails; administrators handle account recovery.

Live since 2026-09-06 (America/Chicago). `warbee` and `lain` are administrators;
Jovan registered as `lain`, was activated, and confirmed successful sign-in.
For the host inventory and routing, see [OCI and Forgejo](../../docs/infra/oci-forgejo.md).
For this repository's replication, see [repository mirroring](../../docs/infra/repository-mirroring.md).

## Provision and deploy

From the repository root, run `nix develop .#forgejo`. The root flake lock pins
the tools. Container references in `compose.yaml` pin both versions and digests.

Save these variables in `infra/forgejo/.env.cloudflare` (ignored by Git), with
mode 0600: `TF_VAR_cloudflare_api_token`, `TF_VAR_cloudflare_account_id`, and
`TF_VAR_cloudflare_zone_id`. Use a token scoped to Tunnel Edit on the account
and DNS Edit / Zone Read on the nebula-1.com zone. MCP OAuth is separate.
Load the trusted local credentials file without printing its contents:

```sh
set -a
source infra/forgejo/.env.cloudflare
set +a
umask 077
tofu -chdir=infra/forgejo init
tofu -chdir=infra/forgejo plan -out=tfplan
tofu -chdir=infra/forgejo apply tfplan
infra/forgejo/deploy.sh
```

Inspect existing tunnel/DNS resources before first apply; import matching
resources into state instead of creating duplicates. OpenTofu state and plans
contain the tunnel token: keep them private and backed up outside Git.

To prepare the application before Cloudflare credentials are available:

```sh
infra/forgejo/deploy.sh --prepare
```

The script builds on the ARM server, previews activation, then switches NixOS.
It uses the verified SSH host alias `stage-db`. Application secrets are generated
on the server once. OpenTofu updates only `.env.tf`; `.env.local` preserves the
database password and Forgejo secret key. Both are root-only. Missing secrets
with existing data cause startup to fail instead of silently rotating them.

## Administrator and signup

Before the tunnel starts, create the initial administrator:

```sh
ssh -o HostKeyAlias=stage-db root@100.123.116.99
/etc/forgejo/bootstrap-admin YOUR_USERNAME YOUR_EMAIL
cat /etc/forgejo/admin-credentials
systemctl start forgejo-tunnel
```

Retrieve the password privately in your own terminal and change it at first login.
The bootstrap helper never resets an existing administrator. The tunnel requires
both `/etc/forgejo/admin-ready` and a nonempty tunnel token. Team members register
at `/user/sign_up`; activate them through user administration and then assign
organization/repository access. Registration does not grant admin rights.

In **Admin settings → Identity & access → User accounts**, open the requested
account, select **Activated account**, and save **Update user account**. Grant
**Administrator account** only when that level of access is intended. Account
activation alone does not grant access to another user's private repositories.

For Git HTTPS, use a personal access token. For Git SSH, add this locally:

```sshconfig
Host git.nebula-1.com
    HostName 100.123.116.99
    User git
    Port 2222
```

The current Git SSH host key fingerprint is
`SHA256:/xy9rGloiUtqBzdjyiYb+UiJbq/F+VvUwHR2Fb4gmVs` (RSA).

## Operations and recovery

On stage-db, use `/etc/forgejo/compose ps`, `journalctl -u forgejo`, and
`/etc/forgejo/compose logs --tail 100 cloudflared`. The tunnel is managed by
`forgejo-tunnel.service`; the application by `forgejo.service`.

The backup timer runs daily at 03:00 America/Chicago. It stops Forgejo writes,
uses native PostgreSQL dumps, archives data and configuration, and restarts
Forgejo on success or failure. Completed backups have checksums and root-only
permissions. Successful backups prune older completed backups after 14 days,
while retaining the newest. Failed/incomplete directories are retained for
inspection. Backups include secrets; they remain local to this server.

```sh
systemctl start forgejo-backup
/etc/forgejo/restore-check /var/backups/forgejo/forgejo-TIMESTAMP /var/lib/forgejo-restore-TIMESTAMP
```

The restore check requires a new destination. It restores into an isolated Docker
network with no published ports or cloudflared connector, starts Forgejo, checks
database counts and Git object integrity, then removes only its test containers.
Restored files remain for inspection. Never point it at production storage.

For actual recovery, stop the tunnel and application, preserve the failed storage,
verify backup checksums, restore `data`, `conf`, and both environment files into
empty production directories, then restore `database.dump` into a fresh PostgreSQL
16 database using the backed-up Compose image references. Start Forgejo and verify
accounts and repositories before restarting the tunnel. For NixOS configuration
rollback, activate the previous retained system generation; database downgrade is
not a substitute for restoring a compatible backup.

For the integration check, run `python3 infra/forgejo/smoke-test.py` locally. It
creates temporary accounts and a private repository, tests manual activation,
PAT-based Git and Tailscale SSH, restarts the application, and checks an isolated
backup restore against the exact committed Git revision. It removes its test
accounts afterwards. This causes a brief application interruption. Public HTTPS
must also be checked after the Cloudflare tunnel has been provisioned.

## Deployment verification — 2026-09-06

- OpenTofu created the managed tunnel, ingress configuration, proxied `git`
  CNAME, and private `.env.tf`. All four cloudflared QUIC connections registered.
- Public HTTPS login and signup returned HTTP 200. Chromium authenticated
  `warbee` at the canonical URL without the alternate-URL warning.
- The integration check passed manual approval, private-repository isolation,
  HTTPS-token semantics over the private test transport, Tailscale Git SSH,
  restart persistence, and an isolated backup restore of the exact Git commit.
- Docker restart recovered the application and retained the first-position
  forwarding guard. A connection from stage-edge over the OCI subnet could
  not reach the Git SSH port.
- A backup including the tunnel configuration completed at
  `2026-09-07T03:03:45Z` (22:03:45 CDT on September 6).

Remaining work: encrypted off-host backups, secure custody of OpenTofu state,
Bitwarden storage of the administrator credentials, and SMTP if automated
account recovery is wanted. Local backups and Git mirrors serve different
purposes: Git replication does not preserve Forgejo accounts, permissions, or
database state. Do not rerun the disruptive integration test while teammates
are working without scheduling its brief outage.
