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

### Object storage (consolidated 2026-09-24)

`services.infra.seaweedfs` (`modules/aspects/database/seaweedfs.nix`) replaces the Docker
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
   its default currently does not (see `modules/aspects/services/maya-worker.nix`).

## Cerberus service retirements

### One local development stack

The target is one always-on ComfyUI server, one Booru web deployment, one
crawler API, and one shared PostgreSQL cluster on Cerberus. A single cluster
can host separate application databases and roles. The two-tier database
layout above describes the existing compatibility split during migration.
Keep additional experiments behind an explicit Compose profile with restart
disabled. Record each always-on service's owner, Compose source, and readiness
check in the deployment runbook.

- **ComfyUI.** `comfyui-api-dev` owns Maya's native port 8188 and wrapper
  port 3030. The idle `nebula-comfyui-h3-still` sidecar on 8199 is stopped
  with restart disabled. Its node set and state differ from the primary.
  TODO: Inventory H3 workflows that still matter, move their required nodes
  and model references into the primary worker, and validate one representative
  workflow before retiring the sidecar's stored state.
- **Booru and crawler.** `dev.booru-internal` and `dev.crawler-api` are the
  sole running web services for their respective stacks. The Booru thumbnail
  worker is paused because it was spending attempts on SeaweedFS connection
  timeouts. Its Compose service requires the `thumbnails` profile.
  TODO: Verify authenticated S3 access from the `dev` bridge, recover stale
  thumbnail claims through the worker's lease path, and prove a canary job
  produces a readable thumbnail before draining the preserved backlog.
- **Manus Langfuse.** The web container had been stopped for three months.
  The worker and its dedicated Postgres, ClickHouse, MinIO, and Valkey are
  stopped with restart disabled. Their Docker volumes are retained.
  TODO: Identify a trace producer and data owner before restoring the stack.
  Recover a supported Compose definition and test one trace from ingestion
  to UI. If no owner needs the history, agree on retention before deleting
  the volumes.

### PostgreSQL consolidation

Use the cluster behind the `warbee-dev-db` alias as the consolidation
candidate. Its current PG19 build serves Booru. `dev.postgres`
still serves the crawler and music worker on PG16, and
`endless-dev-postgres` serves the gateway and browser-history job on PG18.
The two databases called `maya` hold distinct data.

On 2026-11-08 a PG18 `gateway` snapshot restored into an isolated copy of
the current PG19 image. The restore had all 489 user tables, all three
extensions, and matching music observation counts. The live source had one
more RAG chunk when compared after the restore. The restored
`gateway_runtime` role had database connect and public schema usage grants.
The rehearsal used role definitions without passwords and left the live
databases on their original endpoints.

1. Move the PG18 gateway database and the named databases still in use into
   the shared cluster. Reconcile the destination role grants and credential
   references, then quiesce the gateway and history job for the final
   snapshot. Verify both clients on the new endpoint before stopping PG18.
   Keep the original data volume through the rollback window.
2. The current PG19 image lacks Apache AGE. Inventory the live PG16 Cypher
   callers and graph data, port them to the canonical graph model or supply
   a compatible AGE build, then verify graph and relational queries on an
   isolated restore. Restore the PG16 dataset under a distinct database name
   until its overlap with the existing PG19 `maya` has been reconciled.
3. After client cutover, remove the old database services from the default
   startup paths. Verify all clients reconnect to one cluster after a clean
   restart and that the retired database containers stay stopped.

### Penpot (retired)

The local Penpot deployment was removed on 2026-11-08. Its two databases,
Docker assets, and local Compose configuration were archived under
`~/.local/state/nebula/retired/penpot-2026-11-08-DflspI` with checksums.
Both dumps restored in an isolated PostgreSQL instance. The local design
database restored with one file, two projects, and two storage records.
The Compose archive includes the old environment file. Keep the archive
private.

### Standalone Qwen inference container

`llm-qwen38-llamacpp` is retired as an ad hoc deployment. It served
`unsloth/Qwen3.8-27B-GGUF` on port 5808 while the inherited Docker probe
checked port 8080.
Docker removed the temporary container when it stopped. The model cache was
a host bind mount and was kept. The old listener on port 5808 is retired.

- TODO: Register this model through the managed inference router if a caller
  needs it again. Pin the server image and model revision, declare the GPU
  budget and network exposure, and give callers one configured endpoint.
- TODO: Probe the declared listener from the container and from its intended
  caller. Require readiness only once the model is loaded, then verify one
  representative completion and that startup failures are visible.

### Ambient document indexer

`nebula-document-indexer.service` is disabled on Cerberus. The previous unit
pointed into the `workspace-recipe-retrieval` checkout, where the wrapper
could not find a built release binary. Keep the private worker environment,
watch roots, index rows, and objects for recovery.

- TODO: Package the release worker and pinned Poppler tools with a stable
  executable path. Check the private environment, watched directories, and
  PostgreSQL and S3 access before enabling the unit. Expose bounded retries
  and a last successful scan timestamp.
- TODO: Index a fixture under the configured principal and verify retrieval.
  Restart the worker and confirm the same content resolves to the same source
  without duplicate rows or objects. Enable ambient indexing only after the
  canary passes. The existing document upload path is independent.

### Speech Dispatcher output modules

Cerberus uses a per-user allowlist for the working eSpeak NG, eSpeak NG MBROLA,
Flite, and Pico backends. Voxin, Baratinoo, Cicero, Kali, Festival, and Open
JTalk are retired from automatic discovery after their startup helpers became
zombies. Firefox and Vesktop use the socket-activated service.

- TODO: Move the allowlist into the declarative desktop configuration and
  verify that session startup still leaves zero zombie children. Smoke-test
  voice enumeration and speech output in the browser and a desktop client.
- TODO: Restore an individual backend only when a client needs it and its
  runtime, voice assets, and licensing are confirmed. Verify module startup,
  speech playback, and child cleanup after a daemon restart.

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
