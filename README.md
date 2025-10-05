# NixOS dotfiles
This repo contains the nix configurations for my main workstations

## Structure

Under hosts I have the hardware and basic config of each of my hosts, these are divided by their hostname.
```
.

## Usage

To apply changes: `./rebuild-clean.sh` (handles cleanups and nixos-rebuild switch --flake .#dell-potato).

## Code-Server Setup

A code-server container is configured for secure VS Code access in the browser.

- **Access**: `https://localhost:8080` (password: `devsandbox123`)
- **Workspace**: Mounted at `/home/coder/workspace` (maps to `/home/warby/Workspace` on host)
- **Features**: HTTPS with self-signed cert, Nix IDE extension pre-installed, persistent config
- **Management**: Managed via NixOS systemd, view in Portainer at `http://localhost:9000`

Recent updates: Brave with Shazam/Kanagawa/Bitwarden extensions, system dark theming, default browser set. Added code-server container for secure VS Code in browser with HTTPS, mounted workspace at /home/coder/workspace.
├── devtooling -> Direcotry that contains all the configs for my dev tools
│   ├── default.nix
│   ├── git
│   │   └── default.nix
│   ├── gleam
│   │   └── default.nix
│   ├── go
│   │   └── default.nix
│   ├── kubernetes
│   │   ├── default.nix
│   │   └── skin.yml
│   ├── lua
│   │   └── default.nix
│   ├── rust
│   │   └── default.nix
│   └── tmux
│       └── default.nix
├
├── flake.lock
├── flake.nix
├── gtk -> Needed gtk configs
│   ├── conf
│   │   └── default.nix
│   └── default.nix
├── home.nix
├── hosts
│   ├── franktory
│   │   └── etc
│   │       └── nixos
│   │           ├── configuration.nix
│   │           ├── hardware-configuration.nix
│   │           ├── wall-03.jpg
│   │           └── wp2.jpg
│   └── kraken
│       └── etc
│           └── nixos
│               ├── configuration.nix
│               ├── hardware-configuration.nix
│               ├── ollama.nix
│               ├── udev.nix
│               └── wp2.jpg
├── hypr.nix -> Hyrpland configuration
├── hyprpanel.nix -> currently not in use
├── keymaps.nix -> nvim keymaps
├── nixvim -> nvim configurations using nixvim
│   ├── default.nix
│   └── plugins
│       ├── blink
│       │   └── default.nix
│       ├── clipboard-image
│       │   └── default.nix
│       ├── cmp
│       │   └── default.nix
│       ├── code_companion
│       │   └── default.nix
│       ├── dashboard
│       │   └── default.nix
│       ├── git
│       │   └── default.nix
│       ├── harpoon
│       │   └── default.nix
│       ├── hot-reload
│       │   └── default.nix
│       ├── images
│       │   └── default.nix
│       ├── lint
│       │   └── default.nix
│       ├── lsp
│       │   └── default.nix
│       ├── lualine
│       │   └── default.nix
│       ├── luasnip
│       │   └── default.nix
│       ├── markdown-preview
│       │   └── default.nix
│       ├── oil
│       │   └── default.nix
│       ├── packer
│       │   └── default.nix
│       ├── presence
│       │   └── default.nix
│       ├── telekasten
│       │   └── default.nix
│       ├── telescope
│       │   └── default.nix
│       ├── toggleterm
│       │   └── default.nix
│       ├── tree-sitter
│       │   └── default.nix
│       ├── trouble
│       │   └── default.nix
│       └── which-key
│           └── default.nix
├── prompt -> prompt for zsh
│   ├── default.nix
│   └── starship
│       ├── default.nix
│       ├── kanagawa.nix
│       ├── oxocarbon.nix
│       ├── oxo.toml
│       └── tokyonight.nix
├── README.md
├── shelltools -> general tools I use within my terminal\n│   ├── atuin\n│   │   └── default.nix\n│   ├── bat\n│   │   └── default.nix\n│   ├── default.nix\n│   ├── direnv\n│   │   └── default.nix\n│   ├── eza\n│   │   └── default.nix\n│   ├── fzf\n│   │   └── default.nix\n│   ├── yazi\n│   │   └── default.nix\n│   ├── zoxide\n│   │   └── default.nix\n│   └── zsh\n│       └── default.nix\n└── vimopts.nix -> nvim options\n```\n\n## Gaming Setup\n\nGaming is configured via `modules/gaming.nix`, imported in host configurations (e.g., dell-potato). Enable by importing in your host's configuration.nix.\n\n### Key Features:\n- **Steam**: Enabled with remote play and dedicated server support (firewall ports open: 27015-27030 UDP/TCP).\n- **Gamescope**: Compositor for Steam Deck-like experience; run games with `gamescope -w 1920 -h 1080 -- %command%` in Steam launch options.\n- **Gamemode**: Performance optimization; prefix game commands with `gamemoderun` for CPU/GPU boosts.\n- **Mangohud**: FPS/performance overlay; enable with `MANGOHUD=1 %command%` in Steam, or install MangoHud config for custom overlays.\n- **Emulation**:\n  - **RetroArch**: Full build with cores including swanstation (PS1), beetle-psx (PS1 alternative), mame2003 (arcade). Configure via RetroArch UI; BIOS/ROMs in `~/.config/retroarch/`.\n  - **Standalone Emulators**: mgba (GBA), snes9x-gtk (SNES), mednafen (multi-system: NES/SNES/GB/GBA), pcsx2 (PS2), rpcs3 (PS3). Install BIOS as needed.\n- **Wine/Proton**: Lutris (script-based game installs), Heroic Games Launcher (Epic/GOG), wineWowPackages.stable (32/64-bit), protontricks (Winetricks for Proton).\n- **Proton-GE (Glorious Eggroll)**: Custom Proton builds for better compatibility. Install via `protonup-qt` (GUI tool); select versions in Steam > Properties > Compatibility.\n- **Graphics (Intel HD 530, i5-6500 Skylake)**: modesetting driver, OpenGL/VAAPI enabled. Add `intel-media-driver` and `vaapiIntel` for hardware acceleration.\n- **Fuse**: Enabled for Flatpaks/Steam sandboxing.\n\n### Skylake (i5-6500) Optimizations:\n- **Microcode**: Enabled via `hardware.cpu.intel.updateMicrocode = true;` and `hardware.enableRedistributableFirmware = true;` for stability/security.\n- **Kernel**: linuxPackages_zen for better responsiveness/scheduling.\n- **i915 Params**: Add `boot.kernelParams = [ \"i915.enable_psr=0\" ];` if screen tearing; enable early KMS with `boot.initrd.kernelModules = [ \"i915\" ];`.\n- **Power**: Consider `powerManagement.powertop.enable = true;` for tuning, but monitor thermals.\n\n### Troubleshooting:\n- **Deprecated Options**: Update `hardware.opengl` to `hardware.graphics` in gaming.nix; fix VSCode extensions in home.nix to `programs.vscode.profiles.default.extensions`.\n- **Docker Issues**: Ensure user in docker group; restart after rebuild.\n- **Proton-GE Setup**: After install, restart Steam; test with non-native games.\n- **Emulation BIOS**: Manually place BIOS files (e.g., scph5501.bin for PS1) in emulator dirs; not managed by Nix.\n\nRun `./rebuild-clean.sh` after changes. For full rebuild: `sudo nixos-rebuild switch --flake .#dell-potato`. Test games post-reboot for graphics.