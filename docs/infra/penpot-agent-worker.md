# Isolated Penpot design worker

`modules/_features/penpot-design-worker.nix` declares a user session with a
private Xvfb display and Chromium profile. Workspace owns the browser worker,
local Rust design gateway, guarded MCP bridge, PostgreSQL receipt schema and
native board review fixtures. See its
[session runbook](https://git.nebula-1.com/warbee/workspace/src/branch/codex/penpot-session-supervisor/docs/operations/penpot-agent-sessions.md).

The dedicated worker account is separate from the operator account. Login and
MCP credentials, worker execution signing material and the PostgreSQL URL are
looked up in the runtime keyring. Cookies and target IDs live in the private
state directory. No credentials enter the Nix store or agent client settings.

The session starts after login, with a strict three-failure restart ceiling.
It does not depend on Docker, run a Home Manager activation script or share the
operator's display. Chromium sandboxing remains enabled. The browser and local
Rust gateway restart together; unfinished writes remain blocked in PostgreSQL.

`penpot-mcp` exposes only `design_inspect`, `design_apply`, `design_reconcile` and
`design_export`. Its runtime source checkout can be selected in
`~/.config/nebula/penpot-design-session.env`, which the service and bridge both
read. Run `penpot-mcp-register` after the permanent configuration is activated
if a harness still points at an older launcher. Reconnect clients to refresh
their tool list; do not restart unrelated running agents automatically.

The initial live acceptance used the validated, generated Nix unit as a
**transient** user service. Claude Code and Codex were registered to its built
MCP launcher for this review. The worker created, read back and exported native
Maya TTS review boards on OCI. This proves the isolated execution path, not
reboot persistence or shared component publication.

Validation: flake evaluation, formatting, the service-unit derivation and its
MCP-launcher derivation passed. The complete Cerberus toplevel build is blocked
by the existing `chatgpt_amd64.deb` fixed-output hash mismatch. No full NixOS
activation was performed. Resolve that package in its owning change, rebuild,
show changed units as required by `CLAUDE.md`, then activate normally.

The deployed OCI frontend/backend/exporter/MCP images already use 2.18.5. No
remote upgrade, database rewrite or personal browser modification is part of
this worker change. The deployed API has no newer plugin-session selector;
separate credentials and a single connected worker profile provide isolation.
