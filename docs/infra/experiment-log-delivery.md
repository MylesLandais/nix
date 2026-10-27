# Experiment log delivery on Cerberus

The Home Manager module `modules/_features/nebula-otel-home.nix` declares one
collector and a five-minute end-to-end canary check after graphical login.
Configuration lives in `files/observability/experiment-logs.json`; the package
is pinned by this repository's nixpkgs lock (qualified at collector 0.155.0).
No port is opened and no unit depends on Docker starting at boot.

Status on 2026-10-27: **prepared and recovery-tested, not activated**. The full
Cerberus build failed on the existing ChatGPT package fixed-output hash:
expected `sha256-6wgxxzTxVPk/jrzw4X0RjaDep9wXN9xhoecURDdb8ZA=`, received
`sha256-9cm/Lwo9UME5F69hGFp5H1IOWDmQn+qCLYhr41sSGyY=`. Do not replace that
hash blindly or report a successful system build. Native collector validation,
bounded delivery/recovery tests, isolated generated-unit builds, flake evaluation,
module lint and repository formatting checks passed. `systemd-analyze --user
verify` returned zero for the built units; it also reported an unrelated existing
dangling `misskatie-youtube-archive.timer`, which this change does not modify.
The current source checkout's unrelated training-state comments were preserved
by preparing this change in a separate worktree.

## Data path

`filelog` tails private training and generation files under
`/home/warby/Workspace/data/training-state/klein-pilot`. `journald` follows the
two named Comfy containers using the host `journalctl`. New container names
need an explicit selector update. The current config does not start GPU
sampling or claim that the old GPU metrics path is repaired.

File positions, journal cursors and the sending queue use fsync-backed private
storage under the user state directory, `nebula-otel`. The queue batches after
persistent enqueue; no separate volatile batch processor is used. It permits
128 MiB of queued payload, uses one exporter consumer and retries transient
failures without a retry timeout. Queue size is not a hard bound on bbolt file
high-water usage. Full/unwritable storage, permanent backend errors and
unread source rotation remain possible loss conditions that need monitoring.

The destination is the existing loopback ClickHouse HTTP listener at `:8123`,
database `nebula_observability`, native exporter table `live_logs`. Creation
uses the upstream schema and no TTL. Existing crawl/provider tables and the
separate archive-backfill table remain unchanged. Async inserts explicitly
wait for acknowledgement after flush. This is at-least-once delivery: an
ambiguous acknowledgement can cause replay, and producers need stable event
IDs to support logical deduplication. Legacy stdout does not acquire invented
attempt/request identities.

Training run IDs come from the source path. File path, record number and byte
offset are retained. Untimestamped stdout uses observation time in the upstream
table with `event.time.kind=observed_only`; it is not original event time.
Use unique attempt log files before launch; an overwritten file cannot be
recovered if the collector never read the old bytes. The current private queue
was not modified by this deployment preparation.

## Resource and health contract

The collector is limited to one logical CPU and 512 MiB, with a 256 MiB memory
limiter. It starts after graphical login, with bounded restart attempts. It
does not restart ClickHouse or other shared services. The canary unit has
separate lower limits and runs every five minutes after its previous check.

`scripts/check-nebula-log-delivery.py` appends an fsynced synthetic JSON event
with a unique ID, then requires that ID to appear in ClickHouse within the
bounded wait. A failed query/delivery exits nonzero and writes `health.json`
in the collector's state directory. Check its timestamp and service failure
state. This proves the canary file-to-store route, not coverage of every idle
source or NVIDIA metrics. No external notifications are configured here.

After an approved, validated Nix switch:

```sh
systemctl --user status nebula-log-collector.service
systemctl --user status nebula-log-delivery-check.timer
systemctl --user start nebula-log-delivery-check.service
journalctl --user -u nebula-log-delivery-check.service -n 10 --no-pager
```

Only the normal `CLAUDE.md` validation/commit/explicit-confirmation workflow may
activate the host change. Do not copy hand-written units into the user config
directory to bypass it. An unrelated package build failure does not waive that
workflow.

## Evidence and handoff

The Workspace research branch `codex/dev-observability-guidance`,
[PR #75](https://git.nebula-1.com/warbee/workspace/pulls/75), owns the query helper,
recovery-test harness and sanitized receipt. The real-collector test forwards
through an isolated loopback proxy; it refuses a pending export, kills only the
test collector, restarts it with the same storage, and verifies recovery plus
new file/journal delivery and the canary. Shared ClickHouse and GPU jobs remain
running. Observed marker counts are evidence for that scenario, not a universal
exactly-once guarantee.

Validation commands:

```sh
nix flake check --no-build --show-trace
nix build --no-link .#checks.x86_64-linux.treefmt
statix check modules/_features/nebula-otel-home.nix
nix build --no-link --max-jobs 1 --cores 1 .#nixosConfigurations.cerberus.config.system.build.toplevel
```

The first three passed; the final full-host build failed on the package hash
above. Only x86_64-linux checks were evaluated. Isolated Home Manager unit
sources were built using a temporary `pkgs.linkFarm`, without activating them.
Branch baseline is the actual host checkout `30eb066`, ahead of remote `dev`;
review this change relative to that commit, not as a proposal to merge the
entire newer host history into `dev`.
