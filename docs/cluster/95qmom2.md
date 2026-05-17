# 95qmom2 — Data Core (first staging node)

Dell OptiPlex 7050, service tag 95QMOM2. First live node of the staging cluster.

## Hardware

- CPU: Intel i5-6500
- RAM: 12 GB
- sda: 238 GB SSD — sda1 `/boot` (vfat), sda2 swap (8 GB), sda3 `/` (ext4)
- sdb: 9.1 TB HDD — sdb1 `/srv/data` (XFS, label `data`)

Disk UUIDs in `modules/hosts/95qmom2/hardware-configuration.nix`. `/srv/data` was reformatted on 2026-05-16; new UUID `2f206721-500c-409c-b147-a2fdb44544b0`.

## Network

- LAN: `192.168.0.49` on `enp0s31f6` (DHCP from UDM at `192.168.0.1`)
- Tailscale: `100.107.224.21` on tailnet `MylesLandais@`, MagicDNS name `dell-potato`
- LAN firewall opens **22 only**. Tailscale interface opens **22, 5432, 8080, 9333, 18080, 19333**.

If `tailscale status` shows "Logged out", run `sudo tailscale up` on the box and visit the printed URL.

## SSH

```bash
ssh -i ~/.ssh/id_ed25519 warby@192.168.0.49     # LAN
ssh warby@dell-potato                            # Tailscale (MagicDNS)
```

Trusted keys: cerberus, warbpad. Root login disabled, password auth disabled. `warby` has passwordless sudo.

## Postgres 16

Module: `modules/hosts/95qmom2/postgres.nix`. Data dir `/var/lib/postgresql/16` on the SSD.

Roles: `postgres` (preexisting), `warby` (superuser, createdb, createrole, login).

Auth (pg_hba):

```
local all all                  peer
host  all all 127.0.0.1/32     scram-sha-256
host  all all ::1/128          scram-sha-256
host  all all 100.64.0.0/10    scram-sha-256
```

### Connection

```bash
# On-box (peer auth, no password)
sudo -u postgres psql
psql -h /run/postgresql -U warby postgres

# From a tailnet peer (set password first)
sudo -u postgres psql -c "alter role warby with password 'redacted';"
psql "postgresql://warby@dell-potato:5432/postgres"
```

### Common ops

```bash
# Service
systemctl status postgresql
systemctl reload postgresql        # pg_hba reload only
systemctl restart postgresql

# Logs
journalctl -u postgresql -n 200 --no-pager

# Databases
sudo -u postgres psql -c '\l'
sudo -u postgres createdb -O warby myapp
sudo -u postgres psql -d myapp -c 'create extension vector;'

# Existing DBs on this host
#   - phoenix_dev  (preexisting, owner=postgres)
```

### pgvector

Loaded via `shared_preload_libraries = 'vector'`. Confirmed v0.8.2:

```sql
create extension vector;
create table t(v vector(3));
insert into t values ('[1,2,3]');
select v <-> '[0,0,0]' from t;
```

### Tuning

```
shared_buffers          = 2GB
effective_cache_size    = 6GB
work_mem                = 16MB
maintenance_work_mem    = 256MB
max_connections         = 100
wal_level               = replica
```

### Collation drift

This node carries a glibc 2.40 → 2.42 jump. If you see `WARNING: database "X" has a collation version mismatch`:

```sql
alter database X refresh collation version;
```

Reindex any text-keyed index that relied on the old collation ordering.

### Backup hint

`pg_dumpall` over SSH; pgBackRest deferred until cluster has a second node.

## SeaweedFS

Module: `modules/hosts/95qmom2/seaweedfs.nix`. Data under `/srv/data/seaweedfs/{master,volume}`. Master + volume run as the `seaweedfs` system user. SeaweedFS 4.19, package `pkgs.seaweedfs`.

### Topology

| Component | Advertised | Bind | HTTP | gRPC |
|-----------|-----------|------|------|------|
| master    | 100.107.224.21 | 0.0.0.0 | 9333  | 19333 |
| volume    | 100.107.224.21 | 0.0.0.0 | 8080  | 18080 |
| filer     | — (deferred until 2nd node) |

Labels: `dataCenter=home rack=95qmom2 -max=50 volumes`, default replication `000` (single copy — bump when a second volume node lands).

### Upload / download

```bash
# 1. Assign
J=$(curl -s http://dell-potato:9333/dir/assign)
echo "$J"
FID=$(echo "$J" | jq -r .fid)
URL=$(echo "$J" | jq -r .url)

# 2. Put
curl -F file=@./local.bin "http://$URL/$FID"

# 3. Get
curl -O "http://$URL/$FID"
```

### Inspection

```bash
curl http://dell-potato:9333/cluster/status              # leader, peers
curl http://dell-potato:9333/vol/status                  # volume stats
curl http://dell-potato:9333/dir/lookup?volumeId=1       # locate volume
weed shell -master=dell-potato:9333                       # interactive: volume.list, cluster.check
```

### Service ops

```bash
systemctl status seaweed-master seaweed-volume
systemctl restart seaweed-master
journalctl -u seaweed-volume -n 200 --no-pager
```

### Notes

- `-ip=100.107.224.21` is hardcoded in the module. If the node's tailnet IP changes, update `tailscaleIp` in `modules/hosts/95qmom2/seaweedfs.nix`.
- No filer yet, so no S3 gateway and no path-style URLs. Use fids directly.
- Replication is `000` — survives node loss only after a second volume node joins and replication is raised.

## Colmena deploy

Hive lives at `colmena.nix` in the repo root. Node `95qmom2` carries tags `7050 storage data-core postgres seaweedfs`.

```bash
# Build only
nix run nixpkgs#colmena -- build --on 95qmom2 --impure

# Push and activate
nix run nixpkgs#colmena -- apply switch --on 95qmom2 --impure

# By tag (when more nodes exist)
nix run nixpkgs#colmena -- apply switch --on @data-core --impure

# Ad-hoc command
nix run nixpkgs#colmena -- exec --on 95qmom2 -- hostnamectl
```

`--impure` is needed because the dirty git tree carries the flake input `self`. Once changes are committed, `--impure` can be dropped.

See `docs/cluster/colmena.md` for tag taxonomy and the procedure for adding a new node.

## Day-2 ops

- State that matters: `/var/lib/postgresql/16/`, `/srv/data/seaweedfs/`.
- Rollback: `sudo nixos-rebuild --rollback` on the box, or check `nix-env --list-generations --profile /nix/var/nix/profiles/system` and `nix-env --switch-generation N`.
- Where SSH keys come from: `nixosModules.qmom2` in `modules/hosts/95qmom2/configuration.nix`.

## Open items

- Postgres replica (waits on second 7050).
- SeaweedFS filer + S3 gateway (waits on second volume node).
- Tailscale ACL: cerberus is on a different tailnet (`MylesLandais@` vs cerberus's own); admin reaches services via SSH-to-box for now.
- `tailscale up` flow is manual — consider an auth-key in agenix for future nodes.
