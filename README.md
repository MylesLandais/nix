# NixOS dotfiles
This repo contains the nix configurations for my main workstations

## OCI and team Git hosting

The ARM64 OCI hosts run NixOS and use Tailscale for administration. Forgejo is
live at [git.nebula-1.com](https://git.nebula-1.com), served from `stage-db`
through Cloudflare Tunnel. Public signup requires administrator activation.

- [OCI inventory and routing](docs/infra/oci-forgejo.md)
- [Forgejo deployment, signup, backups, and recovery](infra/forgejo/README.md)
- [GitHub source and automatic Forgejo mirror](docs/infra/repository-mirroring.md)

## TODO:
- missing package gemini-cli
- feat:
 with api secrets and inject .env api keys

## Structure

Under hosts I have the hardware and basic config of each of my hosts, these are divided by their hostname.
```
.
├── devtooling -> Direcotry that contains all the configs for my dev tools
│   ├── default.nix
│   ├── git
│   │   └── default.nix
│   ├── gleam
│   │   └── default.nix
│   ├── go
│   │   └── default.nix
│   ├── kubernetes
│   │   ├── default.nix
│   │   └── skin.yml
│   ├── lua
│   │   └── default.nix
│   ├── rust
│   │   └── default.nix
│   └── tmux
│       └── default.nix
├
├── flake.lock
├── flake.nix
├── gtk -> Needed gtk configs
│   ├── conf
│   │   └── default.nix
│   └── default.nix
├── home.nix
├── hosts
│   └── cerberus
│       ├── configuration.nix
│       └── hardware-configuration.nix
├── hypr.nix -> Hyrpland configuration
├── hyprland.nix -> Modular Hyprland configuration
├── hyprpanel.nix -> currently not in use
├── keymaps.nix -> nvim keymaps
├── nixvim -> nvim configurations using nixvim
│   ├── default.nix
│   └── plugins
│       ├── blink
│       │   └── default.nix
│       ├── clipboard-image
│       │   └── default.nix
│       ├── cmp
│       │   └── default.nix
│       ├── code_companion
│       │   └── default.nix
│       ├── dashboard
│       │   └── default.nix
│       ├── git
│       │   └── default.nix
│       ├── harpoon
│       │   └── default.nix
│       ├── hot-reload
│       │   └── default.nix
│       ├── images
│       │   └── default.nix
│       ├── lint
│       │   └── default.nix
│       ├── lsp
│       │   └── default.nix
│       ├── lualine
│       │   └── default.nix
│       ├── luasnip
│       │   └── default.nix
│       ├── markdown-preview
│       │   └── default.nix
│       ├── oil
│       │   └── default.nix
│       ├── packer
│       │   └── default.nix
│       ├── presence
│       │   └── default.nix
│       ├── telekasten
│       │   └── default.nix
│       ├── telescope
│       │   └── default.nix
│       ├── toggleterm
│       │   └── default.nix
│       ├── tree-sitter
│       │   └── default.nix
│       ├── trouble
│       │   └── default.nix
│       └── which-key
│           └── default.nix
├── prompt -> prompt for zsh
│   ├── default.nix
│   └── starship
│       ├── default.nix
│       ├── kanagawa.nix
│       ├── oxocarbon.nix
│       ├── oxo.toml
│       └── tokyonight.nix
├── README.md
├── shelltools -> general tools I use within my terminal
│   ├── atuin
│   │   └── default.nix
│   ├── bat
│   │   └── default.nix
│   ├── default.nix
│   ├── direnv
│   │   └── default.nix
│   ├── eza
│   │   └── default.nix
│   ├── fzf
│   │   └── default.nix
│   ├── yazi
│   │   └── default.nix
│   ├── zoxide
│   │   └── default.nix
│   └── zsh
│       └── default.nix
├── vars.nix -> Global variables
└── vimopts.nix -> nvim options
```

## Hyprland Configuration

The Hyprland configuration is now modular and managed in `hyprland.nix`. It uses variables from `vars.nix` to configure monitors and other settings.

## NVIDIA Configuration

The NVIDIA driver is configured in `hosts/cerberus/configuration.nix`. It uses the open-source kernel modules and is optimized for Hyprland.

## SillyTavern Service

- **Port**: 8765 (changed from 8000 to avoid conflicts)
- **Access**: http://127.0.0.1:8765/
- **Container**: Podman with dedicated system user
- **Documentation**: See `docs/sillytavern/` for detailed guides

## Usage

To apply changes: `sudo nixos-rebuild switch --flake .#cerberus`.

## Source and collaboration

See [nixos Git history and collaboration](docs/infra/git-history.md) for stable/dev branches, preserved history, cloning, and mirror recovery.

The complete source tree lives on `dev`. Release branches (`main` and `stable`)
contain the Cerberus workstation configuration and the shared modules required to
build it; cluster and recovery host entrypoints remain on `dev`.
