# NixOS dotfiles

This repo contains the NixOS + Home Manager configurations for my main workstations.

## Screenshots

![Glance](./assets/glance.png)
![image ](./assets/tmux_btop.png)
![image](./assets/tmux_nvim.png)
![image](./assets/nitch_full_screen.png)
![Image](https://github.com/user-attachments/assets/27fbc144-2977-4a9e-bd4c-798ed0e07922)

## Hosts

| Host | Type | Resolution | Bar | Kernel |
|------|------|------------|-----|--------|
| **franktory** | Laptop | 1920×1080 | noctalia | linux-latest |
| **kraken** | Desktop (dual monitor) | 2×2560×1440 | noctalia | CachyOS |

## Commands

```bash
# Rebuild and switch the full system
nh os switch ~/.config/home-manager

# Rebuild with flake update
nh os switch ~/.config/home-manager --update

# Home Manager only (user-space changes, faster)
home-manager switch

# Format all Nix files
treefmt

# Garbage collect old generations
nh clean all -v
```

## Architecture

The config uses the **dendritic pattern** with [flake-parts](https://github.com/hercules-ci/flake-parts) and [import-tree](https://github.com/vic/import-tree).

- `flake.nix` is a minimal wrapper; `import-tree` auto-discovers modules from three directories:
  - `modules/hosts/` — per-host NixOS configs → `flake.nixosModules.*` / `flake.nixosConfigurations.*`
  - `modules/services/` — reusable NixOS service modules → `flake.nixosModules.*`
  - `modules/flake-parts/` — flake-level exports → `flake.homeManagerModules.*`
- Host-specific data is exposed via typed NixOS options at `options.host.*`; HM modules access them via `osConfig.host.*`
- Shared HM feature modules live in `modules/features/` and are imported explicitly by `modules/home.nix`

## Structure

```
.
├── flake.nix                          # flake-parts wrapper; import-tree scans hosts/, services/, flake-parts/
├── modules/
│   ├── home.nix                       # root Home Manager config (imports all features)
│   ├── packages.nix                   # user packages (home.packages)
│   ├── hosts/                         # auto-scanned by import-tree
│   │   ├── franktory/
│   │   │   ├── default.nix            # flake.nixosConfigurations.franktory
│   │   │   ├── configuration.nix      # flake.nixosModules.franktory
│   │   │   └── hardware-configuration.nix  # flake.nixosModules.franktoryHardware
│   │   └── kraken/
│   │       ├── default.nix            # flake.nixosConfigurations.kraken
│   │       ├── configuration.nix      # flake.nixosModules.kraken
│   │       ├── hardware-configuration.nix  # flake.nixosModules.krakenHardware
│   │       ├── udev.nix               # flake.nixosModules.krakenUdev
│   │       └── logiops.nix            # flake.nixosModules.krakenLogiops
│   ├── services/                      # reusable NixOS modules, auto-scanned by import-tree
│   │   ├── gpu.nix                    # flake.nixosModules.gpu    — AMD/NVIDIA hardware, nvtop, lact
│   │   ├── greeter.nix                # flake.nixosModules.greeter — greetd/tuigreet or SDDM
│   │   ├── ollama.nix                 # flake.nixosModules.ollama  — GPU-aware package selection
│   │   ├── glance.nix                 # flake.nixosModules.glance  — dashboard (port 8080)
│   │   ├── otel.nix                   # flake.nixosModules.otel    — OpenTelemetry collector
│   │   └── prometheus.nix             # flake.nixosModules.prometheus — node exporter + Promtail
│   ├── flake-parts/                   # flake-level exports, auto-scanned by import-tree
│   │   └── homeManagerModules.nix     # flake.homeManagerModules.*
│   └── features/                      # HM modules, imported by home.nix (not scanned by import-tree)
│       ├── host-options.nix           # options.host.{hostName,isDesktop,class,bar,greeter,gpuType,...}
│       ├── env-packages.nix           # flake-input packages injected into environment.systemPackages
│       ├── nix-config.nix             # shared nix daemon config (substituters, gc, optimise)
│       ├── bars/                      # bar modules selected by host.bar
│       │   ├── default.nix
│       │   ├── noctalia.nix
│       │   ├── caelestia.nix
│       │   └── hyprpanel.nix
│       ├── desktops/
│       │   └── hyprland/
│       │       ├── default.nix
│       │       ├── hypr.nix
│       │       ├── hyprlock.nix
│       │       ├── hyprpaper.nix
│       │       ├── wlogout.nix
│       │       └── config/            # animations, bindings, decoration, exec, gestures, windowrules
│       ├── devtooling/                # git, rust, go, lua, gleam, kubernetes, tmux, nixvim
│       ├── shelltools/                # fish, zsh, fzf, eza, bat, direnv, atuin, yazi, zoxide
│       ├── prompt/                    # starship
│       ├── terminals/                 # kitty, ghostty
│       ├── stylix/                    # system-wide Kanagawa Dragon theming
│       ├── gtk/                       # GTK theme config
│       └── flameshot.nix
├── secrets/                           # agenix-encrypted secrets
│   ├── secrets.nix                    # declares SSH public keys for decryption
│   ├── ollama.age
│   └── gemini.age
└── treefmt.toml
```

## Key concepts

### Host options (`options.host.*`)

Each host sets these in its `configuration.nix`. HM modules access them via `osConfig.host.*`.

| Option | Type | Description |
|--------|------|-------------|
| `host.hostName` | `str` | Hostname |
| `host.isDesktop` | `bool` | Whether the machine is a desktop |
| `host.class` | `enum [laptop desktop]` | Form factor |
| `host.bar` | `enum [noctalia caelestia hyprpanel]` | Desktop panel |
| `host.greeter` | `enum [greetd sddm]` | Display manager / greeter (default: `greetd`) |
| `host.gpuType` | `enum [amd nvidia none]` | GPU vendor for driver + tool selection (default: `none`) |
| `host.wallpaper` | `path` | Wallpaper path |
| `host.mainMonitor` | `{ name, width, height, refresh }` | Primary monitor |
| `host.secondaryMonitor` | `{ name, width, height, refresh }` | Secondary monitor |

### Reusable NixOS modules (`flake.nixosModules.*`)

Generic service modules in `modules/services/` can be included in any host's `default.nix`:

| Module | What it provides |
|--------|-----------------|
| `nixosModules.gpu` | `hardware.amdgpu` + `lact` + `nvtopPackages.amd` when `gpuType = "amd"`; `hardware.nvidia` + `nvtopPackages.nvidia` when `gpuType = "nvidia"`; `hardware.graphics` always |
| `nixosModules.greeter` | greetd/tuigreet when `greeter = "greetd"`; SDDM astronaut theme when `greeter = "sddm"` |
| `nixosModules.ollama` | Ollama service; selects `ollama-rocm` / `ollama-cuda` / `ollama` based on `gpuType` |
| `nixosModules.glance` | Glance dashboard on port 8080 |
| `nixosModules.otel` | OpenTelemetry collector (exports to `otelcollector.universe.home`) |
| `nixosModules.prometheus` | Prometheus node exporter + Promtail (uses `host.hostName` as log label) |

### Home Manager modules (`flake.homeManagerModules.*`)

All HM feature modules are exported for reuse by other flakes. Add them to `home-manager.sharedModules` or `home-manager.users.<name>`:

| Module | What it provides |
|--------|-----------------|
| `homeManagerModules.bars` | All bars bundle (selects active bar via `osConfig.host.bar`) |
| `homeManagerModules.barNoctalia` | Noctalia shell bar |
| `homeManagerModules.barCaelestia` | Caelestia shell bar |
| `homeManagerModules.barHyprpanel` | Hyprpanel bar |
| `homeManagerModules.desktops` | Hyprland + hyprlock + hyprpaper + wlogout |
| `homeManagerModules.devtooling` | git, rust, go, lua, gleam, kubernetes, tmux, nixvim |
| `homeManagerModules.shelltools` | fish, zsh, fzf, eza, bat, direnv, atuin, yazi, zoxide |
| `homeManagerModules.prompt` | Starship prompt |
| `homeManagerModules.terminals` | kitty + ghostty |
| `homeManagerModules.stylix` | Kanagawa Dragon base16 theming |
| `homeManagerModules.gtk` | GTK theme config |
| `homeManagerModules.flameshot` | Screenshot tool |

> **Note:** Bar modules require `host-options.nix` as a NixOS module and home-manager used as a NixOS module (not standalone), since they reference `osConfig.host.*`.

> **Note:** `nix flake show` displays `homeManagerModules: unknown` — this is expected; `homeManagerModules` is not a standard flake output type that nix knows how to introspect. The modules are accessible and functional. Verify with: `nix eval .#homeManagerModules --apply builtins.attrNames`

### Module pattern

Every feature module follows this structure:

```nix
{ lib, config, ... }: {
  options.MODULE.enable = lib.mkEnableOption "...";
  config = lib.mkIf config.MODULE.enable { ... };
}
```

Parent modules import sub-modules and enable them by default when the parent is enabled.

### Flake-provided packages

Non-nixpkgs packages injected via `modules/features/env-packages.nix`:

| Input | Package |
|-------|---------|
| `zen-browser` | Browser |
| `helium` | helium2nix custom tool |
| `agenix` | Secret management CLI |
| `opencode` | AI coding assistant |
| `wallpapers` | Kanagawa wallpaper collection |
| `caelestia-shell` / `noctalia` | Desktop panel (selected by `host.bar`) |

### Secrets

Encrypted with [agenix](https://github.com/ryantm/agenix). Files in `secrets/` are `.age` blobs. `secrets/secrets.nix` declares which SSH public keys can decrypt each secret. Decryption requires the corresponding private key at runtime.
