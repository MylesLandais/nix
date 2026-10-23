# Contributing

Conventions for this NixOS configuration. [`CLAUDE.md`](CLAUDE.md) covers the
edit → `/nix-check` → commit → `/nix-switch` workflow and where each kind of change
belongs; this file covers the rules that are easy to violate by accident.

Most of these exist because they were violated. On 2026-08-09 this workstation was
running at load 36 on 12 cores with roughly 183,000 accumulated service restarts
across eleven systemd units and three Docker containers, none of which could ever
have succeeded. Each rule below closes one of the gaps that allowed that.

## 1. Shared developer services are declared, not spun up per project

One Postgres, one Valkey, one object store. Declared in Nix, consumed by projects
over the assigned loopback port. A project compose file must connect to a shared
service rather than starting its own.

The failure mode is not subtle: five Postgres instances and four Valkey instances
were running simultaneously, the Nix-declared copies lost every port race, and
`valkey.service` retried 22,474 times against a port a stale Docker container held.

See [`docs/infra/README.md`](docs/infra/README.md) for the current inventory.

## 2. Ports come from `infra.ingress.localRoutes`

Do not assign ports ad hoc. Duplicate hostnames or ports fail Nix evaluation by
design — that check is the point, so route new services through it rather than
picking a free-looking number.

## 3. Every `Restart=` needs a `StartLimitBurst`

A restart policy without a ceiling turns a permanent misconfiguration into an
infinite loop. `pyload` re-pulled a container image from a registry on all 9,741 of
its restart attempts, which was the single largest source of disk and network churn
on the machine.

```nix
# NixOS system services
systemd.services.foo = {
  startLimitIntervalSec = 300;
  startLimitBurst = 5;
  serviceConfig.Restart = "on-failure";
};

# Home Manager user services — raw systemd directives, and they go in [Unit]
systemd.user.services.foo = {
  Unit.StartLimitIntervalSec = 300;
  Unit.StartLimitBurst = 5;
  Service.Restart = "on-failure";
};
```

Five failures in five minutes is a reasonable default. Pick a wider window for
services that legitimately retry, but never leave it uncapped.

## 4. One host agent service, declarative

No hand-written units in `~/.config/systemd/user/`. They are invisible to review,
survive no rebuild, and drift from the repo.

Two such units invoked `nix-shell` on every restart, so each failure triggered a full
Nix evaluation; between them they accumulated 32,592 restarts. Both are now retired.

If a service belongs on this host, it belongs in a module.

## 5. Prefer cached binaries to compiler flags

Build time is a constraint, not an afterthought.

- No `NIX_CFLAGS`, `-march=`, `-O3`, or `stdenv` overrides. Nothing in the repo does
  this today; keep it that way.
- Run `nix build … --dry-run` before a rebuild and read the *"will be built"* versus
  *"will be fetched"* counts. Overwhelmingly fetched is the healthy result.
- **If a build passes 20 minutes, stop.** Hold the offending input at its previous
  pin or find an alternative derivation. Do not compile through it.
- New `overrideAttrs` / `override` sites need a justification, because an overridden
  derivation always misses the binary cache and builds locally.

### Substituters must be declared system-side

Caches listed only in `flake.nix` under `nixConfig.extra-substituters` are **silently
dropped** unless the invoking user is a `trusted-user` — Nix prints *"ignoring
untrusted flake configuration setting"* and compiles from source instead. Add caches
to `nix.settings.substituters` in
[`modules/_features/nix-config.nix`](modules/_features/nix-config.nix), and keep the
two lists in sync.

This bit us: `noctalia.cachix.org` and `cache.numtide.com` were declared only in
`flake.nix`, so `noctalia` — a direct input with its own bar module — was being built
from source on every bump.

## 6. Version-pinned exceptions are declared, not inferred

Not every duplicate is redundancy. When an instance exists because it is pinned to a
specific version, record why, so a later consolidation pass does not remove it.

Current exception: **`dev.postgres19-canary`, PostgreSQL 19beta2 on `:5434`**, pinned
for the graph language (SQL/PGQ). `dev.booru-internal` is built against it. It is not
a redundant fifth Postgres.

## 7. Mark unresolved issues where they live

Use a `TODO(unsolved)` comment at the point in the code where someone would trip over
the problem, stating what is wrong, why it is unresolved, and what would resolve it:

```nix
# TODO(unsolved): <what is broken> — <why it is still broken>.
# To resolve: <the concrete condition or change that would fix it>.
```

Prefer this to a tracker entry for anything code-adjacent; a marker in the file is
seen by whoever touches it next. Broader issues go to `~/Vault/nix-issues/`.

## 8. Docker on this host is declared, but its containers are not

Cerberus enables `virtualisation.docker` in [`modules/_dev.nix`](modules/_dev.nix)
with `enableOnBoot = false`: dockerd is socket-activated and starts on the first
`docker` call. The dev stack itself (compose projects, restart-policy containers)
is still not declared in Nix. Its containers come back whenever dockerd starts, by
accident rather than by configuration. Either declare a container or remove it.
Do not add to the stack on the assumption that it is managed.

## 9. Nothing heavy on the boot path

Cerberus has a fast boot budget, and it has been lost twice. On 2026-09-25 a cold
boot took 2m05s to reach `graphical.target` and 36s of Home Manager activation
before the greeter appeared. A warm reboot of the same generation took 24s. One
line caused the gap: `llama-swap` declared `requires = [ "docker.service" ]`. That
started dockerd at boot despite socket activation, and dockerd restored about 25
containers at once (fixed in `d725d2c`).

**Know what the greeter waits on.** `display-manager.service` waits for
`systemd-user-sessions.service`, which waits for `home-manager-warby.service`. Every
`home.activation.*` script therefore runs at boot, before the login screen.

**The root disk turns contention into delay.** `/` and `/nix` sit on a Crucial P3
(QLC, DRAM-less, ~77% full). Anything that starts alongside activation slows
activation by 5–10×. In the example above, the hermes activation step took 20s at
boot and takes 0.3s warm.

Rules:

- **Never pull Docker in at boot.** A unit `wantedBy` `multi-user.target` may order
  `after = [ "docker.service" ]`, but it must not use `requires`, `wants`, `bindsTo`
  or `partOf` on it. The `docker` CLI reaches `/run/docker.sock`, which starts
  dockerd on demand.
- **Ask whether a new boot service needs to run before login.** Most don't. Prefer
  socket activation, a timer, or a Home Manager user service `wantedBy`
  `graphical-session.target`, in that order. Reserve `multi-user.target` for things
  the machine is broken without.
- **Keep `home.activation` scripts cheap and idempotent.** No network, no package
  manager, no spawning of CLIs that boot a runtime (Node, Python, Electron). Check
  state first and do nothing when it is already correct. `blenderMcp` runs
  `codex mcp add` on every activation, which costs ~4s at boot. It is the example to
  not copy.
- **Measure on a cold boot.** A warm reboot hides disk contention and will
  understate a regression by minutes.

Checks after any change that adds a service, an activation script, or a dependency:

```bash
systemctl show docker.service -p WantedBy,RequiredBy   # both must be empty
systemd-analyze critical-chain display-manager.service # what the greeter waited on
systemd-analyze critical-chain graphical.target
journalctl -b -u home-manager-warby -o short-monotonic | grep Activating  # per-step time
cat /proc/pressure/io                                   # sustained "some" > ~10% = contention
```
