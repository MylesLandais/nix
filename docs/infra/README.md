# Infra demo (cerberus)

Cerberus-local SSO + OpenBao service accounts for Maya.

> **Status: disabled as of 2026-08-09.** `infra.demo.enable` is `false` in
> [`modules/hosts/cerberus/configuration.nix`](../../modules/hosts/cerberus/configuration.nix).
> Every spine service lost its port to the Docker dev stack this workstation already
> runs and then retried forever — valkey 22,474 restarts, pyload 9,741, authentik
> 1,162 × 3, maya-bot 11,534. See [Shared developer services](#shared-developer-services)
> for what has to be true before turning it back on.

## Stack

- **Authentik** — human SSO (`warby` user)
- **Traefik** — ForwardAuth ingress (HTTP demo mode on port 80)
- **OpenBao** — `maya-agent` AppRole for Discord + pyLoad creds
- **Postgres / Valkey** — Authentik backends

## Enable

In [`modules/hosts/cerberus/configuration.nix`](../modules/hosts/cerberus/configuration.nix):

```nix
infra.demo.enable = true;
```

## DNS and local routes

Nix generates local host entries for routes declared in
`infra.ingress.localRoutes`; do not assign repository ports ad hoc.

| Repository | Canonical URL | Loopback port |
| --- | --- | ---: |
| `tint` | `http://tint.localhost` | `45173` |

The repository must bind its assigned port with strict-port behavior. Traefik
owns port 80 and forwards the hostname to that loopback port, including
WebSocket traffic. Use the direct port only for diagnostics. Duplicate local
hostnames or ports fail Nix evaluation.

## Shared developer services

The rule above — *do not assign repository ports ad hoc* — applies to backing
services too, not just HTTP routes. It was not enforced for them, and the result
is that this workstation runs the same infrastructure many times over, with the
Nix-declared copy losing the port race every time.

**Principle:** one instance per service, declared in Nix, consumed by projects over
its assigned loopback port. A project compose file should connect to a shared
service, never start its own.

Snapshot of the violations, 2026-08-09 (42 containers across 16 compose projects):

| Service | Instances found | Target |
| --- | ---: | --- |
| Valkey / Redis | 4 — `dev.valkey` (:6379), ~~penpot 8.1~~ (dropped 2026-09-06), langfuse 8-alpine, Nix `valkey.service` | 1, Nix-managed on `:6379` |
| Postgres | 5 — `dev.postgres` 16.13 (:5433), `dev.postgres19-canary` **19beta2** (:5434), ~~penpot pg15~~ (dropped 2026-09-06), langfuse pg16, Nix `postgresql_16` (:5432) | **2** — see the tier table below |
| Object storage | ~~2 — minio (dead), `dev.seaweedfs`~~ (consolidated 2026-09-24) | 1, Nix-managed on `:8333` (S3), `:9333` (master), `:8888` (filer) |
| Host agent | 4 — maya-bot ×3, hermes-agent | 1 |

### Database tiers (established 2026-09-06)

Postgres consolidates onto **two** instances, addressed by canonical aliases on the
`dev` Docker network rather than by container name. Both are declared in
`~/Workspace-internal/src/crawler/docker-compose.yml`.

| Tier | Alias | Version | Loopback | Container |
| --- | --- | --- | ---: | --- |
| **beta** — default for new work | `warbee-dev-db` | 19beta2 | `:5434` | `dev.postgres19-canary` |
| **stable / LTS** — fallback | `warbee-dev-db-stable` | 16.13 | `:5433` | `dev.postgres` |

The beta tier is the default target: new consumers connect to `warbee-dev-db` and
get SQL/PGQ and everything else 19 adds. The stable tier exists for consumers that
cannot run on a pre-release — a fallback, not a second default. Any consumer should
be able to switch tiers by changing one host variable; wire that variable rather
than hardcoding a hostname.

The alias is deliberately not the container name. `dev.postgres19-canary` keeps its
name and its SQL/PGQ canary role, so `dev.booru-internal` (built against
`workspace-internal-booru:pg19`) and every other existing caller keeps resolving
what it already resolves. Nothing is migrated implicitly; cutovers are per-caller.

**Beta means beta.** 19beta2 is pre-release and its on-disk format is not guaranteed
stable across beta revisions — a `19beta3` bump may require dump/restore rather than
a binary upgrade. Do not put anything on the beta tier whose loss would hurt without
a dump. Note the stage environment pins `19beta3`
(`~/Workspace-end/nix/stage/modules/postgres.nix`); local is one revision behind.

Verify a consumer against the beta before cutting it over, rather than assuming.
Penpot 2.16.2 was checked this way on 2026-09-06 — a throwaway database, all 151
migrations applied, backend booted — and then moved.

#### Not yet on a tier

These still run their own Postgres and are unconverted:

- `endless-dev-postgres` — PG18 on `:5432`, from `~/Workspace-end/docker/compose.dev.yaml`.
  Also the reason the Nix-declared `services.infra.postgres` loses the `:5432` port
  race, and therefore why `infra.demo.enable` is still `false`.
- `manus-langfuse-postgres-1` — PG16, langfuse-internal, not published.

### Experiment log delivery

See [experiment log delivery](experiment-log-delivery.md) for the prepared
collector, persistent queue/cursors, ClickHouse destination and end-to-end
canary. Recovery tests passed; activation remains blocked on a separate
ChatGPT package hash mismatch in the full Cerberus build.

### Object storage (consolidated 2026-09-24)

`services.infra.seaweedfs` (`modules/database/seaweedfs.nix`) replaces the Docker
container `dev.seaweedfs`. Single-node `weed server` (master + volume + filer + S3),
running as `warby`, `-dir=/srv/data/seaweedfs-data` — the same data directory the
Docker container migrated onto via `scripts/cutover_seaweedfs.sh`
(Workspace-internal), so the `raw-data` bucket and its contents carried over with no
re-upload.

Bound `0.0.0.0`, not loopback-only like Valkey's default: Docker containers on the
`dev` bridge reach it via `host.docker.internal` (a host-gateway route to the host's
real interface, which a strict `127.0.0.1` bind would refuse), and it is not opened
on `tailscale0` — off the tailnet/LAN. Host-run scripts already default to
`http://localhost:8333` (see e.g. `src/crawler/config.py`), so they're unaffected.

S3 identities/bucket grants come from `~/.local/share/seaweedfs-config/s3.json`
(outside the Nix store — holds credentials, predates this module): `collector`
(`raw-data`, `browser`), `endless-music` (`music`), `maya` (admin), `vision`
(`vision-archive`), `nebula-music-inbox` (`downloads`).

Docker-network consumers (compose files using the `dev.seaweedfs:8333` hostname)
were repointed at `http://host.docker.internal:8333` with the matching
`extra_hosts: ["host.docker.internal:host-gateway"]` entry — the same idiom
`maya-unified/infra/docker-compose.dev.yml` already used for reaching ComfyUI on
the host. Updated: `Workspace-internal/src/crawler/docker-compose.yml` (also
dropped its own `seaweedfs` service block and volume),
`Workspace-internal/docker-compose.booru.yml`, `maya-unified/infra/docker-compose.dev.yml`.

### Re-enabling the demo spine

`infra.demo.enable = true` is safe again once:

1. Exactly one Postgres answers `:5432` and holds the `authentik` role.
2. Exactly one Valkey answers `:6379`, with no container publishing that port.
3. Authentik's secret key comes from agenix, not the checked-in demo placeholder.
4. `services.infra.mayaWorker.workspacePath` points at a directory that exists —
   its default currently does not (see `modules/services/maya-worker.nix`).

## Before rebuild

```bash
docker stop dev.traefik 2>/dev/null || true
```

## Rebuild

```bash
nix build .#nixosConfigurations.cerberus.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#cerberus
```

## Authentik first boot

1. http://auth.homelab.lan/if/flow/initial-setup/
2. Create user `warby`
3. Application → Proxy provider → `http://downloads.homelab.lan`
4. Deploy Traefik outpost; update token in authentik-outpost service

## Smoke tests

See [`secrets/README.md`](../secrets/README.md) for OpenBao bootstrap.

```bash
curl -I http://downloads.homelab.lan
curl -I http://tint.localhost
systemctl status maya-bot openbao authentik-server pyload
```
