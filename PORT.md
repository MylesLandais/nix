# Port checklist: warby/nix → FKouhai/nix-dots dendritic layout

Working dir: `~/Workspace/nix-dots-fork` on branch `dendritic`.
Remote `origin` = `git@github.com:MylesLandais/nix.git` (existing repo).
Remote `upstream` = `https://github.com/FKouhai/nix-dots.git` (Frankie).

Source repo for this port: `~/.config/nixos` (dirty working tree — port from HEAD, not from uncommitted changes unless flagged).

## Status legend

- [x] done · [ ] todo · [~] partial · [skip] not porting

## modules/ (current repo) → modules/features/ (fork)

| Source                              | Target                                                         | Notes                                                                            |
| ----------------------------------- | -------------------------------------------------------------- | -------------------------------------------------------------------------------- |
| `modules/agenix.nix`                | host-level wiring + `secrets/` reuse                           | Frankie already uses agenix; just re-encrypt our secrets to his layout.          |
| `modules/chromium.nix`              | `modules/features/browsers/chromium.nix` (new dir)             | Just landed; ports cleanly. Shazam ext stays.                                    |
| `modules/firefox.nix`               | `modules/features/browsers/firefox.nix`                        | Same.                                                                            |
| `modules/dev.nix`                   | fold into `modules/features/devtooling/default.nix`            | Generic dev shell bits.                                                          |
| `modules/gaming.nix`                | `modules/features/gaming.nix` (new)                            | cerberus-only via host flag.                                                     |
| `modules/gnome-keyring.nix`         | `modules/features/gnome-keyring.nix` (new)                     | cerberus.                                                                        |
| `modules/hermes.nix`                | `modules/features/hermes.nix` (new) + flake input              | Needs `hermes-agent` input added to fork's flake.                                 |
| `modules/nvidia.nix`                | merge into `modules/services/gpu.nix` (gpuType="nvidia" branch) | Frankie's `gpu.nix` already gates on `host.gpuType`.                              |
| `modules/pentest.nix`               | `modules/features/profiles/pentest.nix` (new)                  | Gated by new `host.profile = "pentest"` option.                                  |
| `modules/pro.nix`                   | `modules/features/pro.nix` (new)                               | Review what's in there before porting.                                            |
| `modules/python.nix`                | `modules/features/devtooling/python.nix` (new)                 | Slot under devtooling.                                                            |
| `hypr.nix`                          | merge into `modules/features/desktops/hyprland/`               | Diff our keybinds/window rules against his.                                      |
| `hyprpanel.nix`                     | [skip]                                                         | Replaced by `host.bar = "noctalia"`.                                             |
| `patches/hyprpanel-desc-workspace-rules.patch` | [skip]                                              | Bar gone.                                                                        |
| `gtk/`                              | merge into `modules/features/gtk/`                             | Diff configs.                                                                    |

## devtooling/ (current) → modules/features/devtooling/ (fork)

Frankie has: git, gleam, go, kubernetes, lua, nixvim, rust, tmux.

| Source              | Target                                              | Notes                                                                |
| ------------------- | --------------------------------------------------- | -------------------------------------------------------------------- |
| `git/`              | merge into upstream `git/`                          | Diff and reconcile.                                                  |
| `gleam/`            | merge into upstream `gleam/`                        | Diff and reconcile.                                                  |
| `go/`               | merge into upstream `go/`                           | Diff and reconcile.                                                  |
| `kubernetes/`       | merge into upstream `kubernetes/`                   | Diff and reconcile.                                                  |
| `lua/`              | merge into upstream `lua/`                          | Diff and reconcile.                                                  |
| `rust/`             | merge into upstream `rust/`                         | Diff and reconcile.                                                  |
| `tmux/`             | merge into upstream `tmux/`                         | Diff and reconcile.                                                  |
| `claude-code/`      | new `devtooling/claude-code/` + flake input         | Add `claude-code-nix` overlay to fork.                                |
| `code/`             | new `devtooling/code/`                              | vscode setup.                                                        |
| `vscode-ai/`        | new `devtooling/vscode-ai/`                         | Add `nix-vscode-extensions` input.                                   |
| `zed/`              | new `devtooling/zed/` + flake input                 | Add `zed` input.                                                     |
| `elixir/`           | new `devtooling/elixir/`                            |                                                                      |
| `nushell/`          | new `devtooling/nushell/`                           |                                                                      |
| `remmina/`          | new `devtooling/remmina/`                           |                                                                      |
| `pi/`               | new `devtooling/pi/`                                | Pi-related tooling.                                                  |
| `browser-mcp/`      | new `devtooling/browser-mcp/`                       |                                                                      |

## shelltools/ (current) → modules/features/shelltools/ (fork)

Identical directory listing on both sides (atuin, bat, direnv, eza, fish, fzf, yazi, zoxide, zsh). Diff and merge each — likely cosmetic.

## scripts/ (current) → modules/features/bootstrap/ (new) + per-host

| Source                                    | Target                                                    | Notes                                                                |
| ----------------------------------------- | --------------------------------------------------------- | -------------------------------------------------------------------- |
| `bootstrap-lacie.sh`                      | `modules/features/bootstrap/` (gated on `host.imaging.enable`) | Lacie's whole reason for existing.                                   |
| `setup-lacie-secretcon.sh`                | same                                                      | Twin-host setup script.                                              |
| `setup-nix-usb.sh` + `setup-nix-usb.QA.md`| same                                                      | USB imaging.                                                         |
| `code-server-diagnostics.sh`              | `modules/features/devtooling/code/` or skip              | Decide if still used.                                                |
| `code-server-monitor.sh`                  | same                                                      |                                                                      |
| `hyprland-debug.sh`                       | `modules/features/desktops/hyprland/`                     |                                                                      |
| `monitor-dpms.sh`                         | `modules/features/desktops/hyprland/`                     |                                                                      |
| `update-hermes.sh`                        | next to `hermes.nix` feature                              |                                                                      |

## secrets/ (current) → secrets/ (fork)

| Source                | Target                                | Notes                                                            |
| --------------------- | ------------------------------------- | ---------------------------------------------------------------- |
| `hermes-env.age`      | `secrets/hermes-env.age`              | Re-encrypt with same age keys.                                  |
| `ollama.age`          | `secrets/ollama.age`                  |                                                                  |
| `zai-api-key.age`     | `secrets/zai-api-key.age`             |                                                                  |
| `secrets.nix`         | `secrets/secrets.nix`                 | Reconcile recipient list with Frankie's.                         |

## hosts/ (current) → modules/hosts/ (fork)

Order: lacie → secretcon → cerberus.

### lacie

- `host.class = "laptop"`, `host.bar = "noctalia"`, `host.theme = "kanagawa-dragon"`.
- `host.imaging.enable = true;` (new option to add to host-options).
- Hardware: copy `hosts/lacie/hardware-configuration.nix` verbatim.
- Bootstrap scripts wired in via `imaging` feature.

### secretcon

- `host.class = ?` (laptop assumed — confirm during port).
- `host.primaryUser = "kali"` (new option).
- `host.profile = "pentest"` (new option).
- Stub `warby` user as today (home-manager eval requirement of shared modules).

### cerberus

- `host.class = "desktop"`, `host.gpuType = "nvidia"`, `host.bar = "noctalia"`, `host.greeter = "sddm"`.
- New input: `nix-cachyos-kernel` — use Frankie's kraken pattern.
- New input: `chaotic` (`chaotic-cx/nyx`) — for nyxpkgs.
- New input: `hermes-agent`.
- New input: `claude-code-nix`, `nix-vscode-extensions`, `cursor-flake`, `zed`, `opencode`, `thorium`, `tokyonight`, `nur`.
- New `modules/features/desktops/sddm-nvidia.nix`: software-render greeter env workaround.
- Sudo NOPASSWD rules: port from `hosts/cerberus/configuration.nix`.

## host-options.nix extensions (new)

- `host.primaryUser : str` (default "warby")
- `host.profile : enum [ "default", "pentest" ]` (default "default")
- `host.imaging.enable : bool` (default false)

## flake.nix extensions

Add inputs (cerberus): `nix-cachyos-kernel`, `chaotic`, `hermes-agent`, `claude-code` (sadjow/claude-code-nix), `nix-vscode-extensions`, `cursor-flake`, `zed-industries/zed`, `anomalyco/opencode`, `Rishabh5321/thorium_flake`, `mrjones2014/tokyonight.nix`, `nix-community/NUR`, `0xc000022070/zen-browser-flake` (already upstream).

## Cutover

1. `nix flake check` green from fork root.
2. `nix build .#nixosConfigurations.{lacie,secretcon,cerberus}.config.system.build.toplevel` all green.
3. cerberus dry-activate green.
4. cerberus live switch on a quiet evening — fallback generation pinned.
5. Lacie live-USB rebuild + bootstrap test.
6. Secretcon kali login test.
7. Push `dendritic` to `origin` (= `MylesLandais/nix`).
8. Rename `~/.config/nixos` → `~/.config/nixos.legacy.YYYYMMDD`, move fork in.
9. Update `.claude/commands/nix-{check,switch}.md` and CLAUDE.md.
10. Merge `dendritic` → `main`.
11. Delete this `PORT.md`.
