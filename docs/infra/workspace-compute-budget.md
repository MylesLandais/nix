# Workspace compute budget

Requested 2026-10-22 by the workspace owner. First stage implemented the same day
on `nightly/2026.10.22`. The policy favors desktop responsiveness, limits workspace
background compute to six logical CPUs of CPU time, and drains active game and
automation sessions before restarts or migrations. Source optimizations are on the
monorepo branch `codex/workspace-performance`; see its
`docs/operations/workspace-performance.md`.

## Implemented

| Scope | Where | CPU | Memory |
| --- | --- | --- | --- |
| `workspace.slice` (user): every `nebula-*` unit via a prefix drop-in, plus `chrome-cdp.service` | `modules/_features/workspace-budget-home.nix` | `CPUQuota=400%`, `CPUWeight=20` | `MemoryHigh=24G`, `MemoryMax=32G`, oomd kill at 60% pressure |
| `workspace-host.slice` (system): `nix-daemon` and its builders | `modules/_features/workspace-budget.nix` | `CPUQuota=200%`, `CPUWeight=20`, `IOWeight=20`; Nix `max-jobs=1`, `cores=2` | `MemoryHigh=24G`, `MemoryMax=32G` |

Deviations from the proposal below:

- Host memory is 24G/32G, not 12G/16G. `nix-daemon` measured a 26G peak, and
  limits may not sit below current use.
- No IO weight on the user slice. The user manager delegates only cpu, memory and
  pids.
- Running units keep their current slice. The drop-in applies when a `nebula-*`
  unit next starts, so nothing was moved mid-session.

Still open:

- Docker containers. `docker.service` restarts on any `daemon.json` change
  (`restartIfChanged`, no `live-restore`), so setting `cgroup-parent` restarts
  Postgres, vLLM and the crawler. vLLM's `--cpu-offload-gb` also exceeds a 32G
  ceiling. This needs the inventory and a drained window.
- Agent/QA Chromium (`app-org.chromium.Chromium-*.scope`, peaks of 68G and 13.7G
  measured). These scopes can't be told apart from personal Chromium by name, so
  the monorepo launcher should start them with `systemd-run --user --slice=workspace.slice`.
- Shared build/QA admission across worktrees.
- A large cache-miss rebuild is bounded by the 200% host quota even with explicit
  `--max-jobs/--cores`. For one deliberate build, lift it at runtime:
  `sudo systemctl set-property --runtime workspace-host.slice CPUQuota=`,
  and restore it with a reboot or by setting `200%` again.

## Observed configuration

Cerberus has six physical cores and twelve logical CPUs. The workspace inspection
sampled load around 40 and CPU pressure around 81 percent. The transient user
unit `nebula-pokeforce-gateway.service` ran `maya_draft_server` at 137 percent CPU
in a fresh sample and had no CPU or memory cap. Some QA, game, and build processes
inherited a Chromium application scope instead of a workspace-specific scope.

The effective `/etc/nix/nix.conf` contains `max-jobs = auto` and `cores = 0`.
These permit parallel derivations and request all detected cores per derivation.
`nix-daemon.service` had no CPU or memory cap. Its local build descendants need
to be included in any enforcement test; setting Cargo jobs alone cannot bound
Nix or concurrent builds in other worktrees.

## Original proposal

- Inventory current units, launchers, containers, owners, and shared-service
  dependencies before assigning limits. Follow CONTRIBUTING.md's service
  consolidation rules; this task does not call for creating more infrastructure.
- Declare Cerberus-specific system and user resource policy in the owning NixOS
  and Home Manager modules. The monorepo should consume those units through its
  maintained launchers, without embedding machine-specific system policy.
- Start with an aggregate 400 percent CPU ceiling for workspace user workloads
  and 200 percent for Nix and identified workspace host workloads. These total
  600 percent across both managers; separate 600 percent ceilings would not meet
  the requested budget. Prefer runtime services over batch jobs with CPU weights.
- Set Nix local parallelism to one derivation with two build cores. Verify the
  daemon's descendants and any builder scopes remain covered by the host budget.
- Review initial memory thresholds against measured peaks: user workloads at
  24 GiB high / 32 GiB maximum and host workloads at 12 / 16 GiB are starting
  proposals, not deployed settings. Do not impose hard limits below current use.
- Make build/QA admission shared across worktrees. A per-process worker count
  does not prevent several agents from each starting their own large job.
- Keep personal browser sessions and unrelated services outside the workspace
  limits. Report workspace processes that remain outside their intended groups.
- Apply compatible CPU controls live where possible; drain sessions before
  moving units between slices, restarting services, or recreating containers.
  Preserve volumes, secrets, pairing state, and gameplay checkpoints.

## Acceptance and activation

Exercise simultaneous runtime, Cargo/QA, and Nix workloads. Inspect effective
`cpu.max`, `cpu.stat`, memory events, pressure, and descendant placement; verify
the two aggregate CPU ceilings and normal gateway/game behavior. Keep the prior
generation and service configuration available for rollback.

Follow CLAUDE.md before activation: inspect the current dirty tree, validate and
build Cerberus without activation, show every changed service and its ExecStart
diff, and identify all active dependents. This repository already contained
unrelated changes when these notes were added. Do not include or activate those
changes as part of a compute-budget rollout without reviewing their effects.
