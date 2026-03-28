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

- `flake.nix` is a minimal wrapper; `import-tree` auto-discovers host modules from `modules/hosts/`
- Every `.nix` file under `modules/hosts/` is a valid flake-parts module — including hardware configs and sub-modules — each exporting `flake.nixosModules.<name>` or `flake.nixosConfigurations.<host>`
- Host-specific data is exposed via typed NixOS options at `options.host.*`; HM modules access them via `osConfig.host.*`
- Shared NixOS feature modules live in `modules/features/` and are imported explicitly

## Structure

```
.
├── flake.nix                          # flake-parts wrapper; auto-discovers modules/hosts/
├── home.nix                           # root Home Manager config
├── packages.nix                       # user packages (home.packages)
├── modules/
│   ├── hosts/                         # auto-scanned by import-tree (all files are flake-parts modules)
│   │   ├── franktory/
│   │   │   ├── default.nix            # flake.nixosConfigurations.franktory
│   │   │   ├── configuration.nix      # flake.nixosModules.franktory
│   │   │   └── hardware-configuration.nix  # flake.nixosModules.franktoryHardware
│   │   └── kraken/
│   │       ├── default.nix            # flake.nixosConfigurations.kraken
│   │       ├── configuration.nix      # flake.nixosModules.kraken
│   │       ├── hardware-configuration.nix  # flake.nixosModules.krakenHardware
│   │       ├── ollama.nix             # flake.nixosModules.krakenOllama
│   │       ├── glance.nix             # flake.nixosModules.krakenGlance
│   │       ├── udev.nix               # flake.nixosModules.krakenUdev
│   │       ├── logiops.nix            # flake.nixosModules.krakenLogiops
│   │       ├── otel.nix               # flake.nixosModules.krakenOtel
│   │       └── prometheus.nix         # flake.nixosModules.krakenPrometheus
│   └── features/                      # NixOS/HM modules (not scanned by import-tree)
│       ├── host-options.nix           # defines options.host.{hostName,isDesktop,class,bar,wallpaper,mainMonitor,secondaryMonitor}
│       ├── env-packages.nix           # flake-input packages injected into environment.systemPackages
│       ├── nix-config.nix             # shared nix daemon config (substituters, gc, optimise)
│       ├── bars/                      # desktop-agnostic bar modules (reusable across WMs)
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
│       ├── prompt/                    # starship (kanagawa / oxocarbon / tokyonight themes)
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

Each host sets these in its `configuration.nix` (as `flake.nixosModules.<host>`):

| Option | Type | Description |
|--------|------|-------------|
| `host.hostName` | `str` | Hostname |
| `host.isDesktop` | `bool` | Whether the machine is a desktop |
| `host.class` | `enum [laptop desktop]` | Form factor |
| `host.bar` | `enum [noctalia caelestia hyprpanel]` | Desktop panel |
| `host.wallpaper` | `path` | Wallpaper path |
| `host.mainMonitor` | `{ name, width, height, refresh }` | Primary monitor |
| `host.secondaryMonitor` | `{ name, width, height, refresh }` | Secondary monitor |

HM modules access these via `osConfig.host.*`.

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
