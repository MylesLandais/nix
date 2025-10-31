# NixOS Configuration

This repository contains the complete NixOS configuration for my workstations, with a focus on declarative system management and containerized services.

## Current Status

### Working Services
- **SillyTavern**: Fully functional LLM frontend running on port 8765
  - Containerized deployment using Podman
  - Proper security configuration with whitelist
  - Multi-user support ready
  - Health monitoring and logging

### System Architecture

```
nix/
├── docs/                    # Documentation
│   └── sillytavern/         # SillyTavern-specific docs
│       ├── deployment-guide.md
│       ├── dev-guide.md
│       ├── implementation-summary.md
│       └── infrastructure-architecture.md
├── hosts/                   # Host-specific configurations
│   └── cerberus/           # Main workstation config
│       ├── configuration.nix
│       └── hardware-configuration.nix
├── modules/                 # Reusable NixOS modules
│   ├── sillytavern.nix        # SillyTavern service module
│   ├── agenix.nix
│   ├── dev.nix
│   ├── gaming.nix
│   ├── gnome-keyring.nix
│   ├── jupyter-image.nix
│   ├── pro.nix
│   ├── python.nix
│   ├── sunshine.nix
│   └── [other modules...]
├── devtooling/              # Development tool configurations
├── gtk/                     # GTK theme configurations
├── nixvim/                  # Neovim configuration
├── prompt/                  # Shell prompt configurations
├── shelltools/              # Command-line tools
├── secrets/                 # Encrypted secrets (agenix)
├── flake.nix                # Main flake configuration
├── home.nix                 # Home Manager configuration
├── vars.nix                 # Global variables
├── hyprland.nix             # Hyprland WM configuration
├── treefmt.toml             # Code formatting
└── .gitignore               # Git exclusions
```

## Key Features

### SillyTavern Service
- **Port**: 8765 (changed from 8000 to avoid conflicts)
- **Access**: http://127.0.0.1:8765/
- **Container**: Podman with dedicated system user
- **Security**: Whitelist configured for Podman network (10.88.0.1)
- **Data Persistence**: `/var/lib/sillytavern`
- **Health Checks**: Built-in monitoring with 60s startup period

### Development Environment
- **Neovim**: Configured with nixvim and extensive plugin ecosystem
- **Shell**: Zsh with starship prompt and useful tools
- **Languages**: Go, Rust, Elixir, Python, Lua, Kubernetes tooling
- **Git**: Proper configuration with signing and useful aliases

### Desktop Environment
- **Window Manager**: Hyprland with multi-monitor support
- **Display**: NVIDIA proprietary drivers with Wayland support
- **Theme**: Catppuccin Mocha with consistent styling
- **Applications**: Ghostty terminal, VSCode, MPV, Nemo file manager

## Usage

### **System Updates**
```bash
# Apply configuration changes
sudo nixos-rebuild switch --flake ".#cerberus"

# Build without applying
sudo nixos-rebuild build --flake ".#cerberus"

# Check configuration
sudo nixos-rebuild dry-build --flake ".#cerberus"
```

### **Service Management**
```bash
# Check SillyTavern status
systemctl status podman-sillytavern.service

# View SillyTavern logs
journalctl -u podman-sillytavern -f

# Restart SillyTavern
sudo systemctl restart podman-sillytavern.service
```

### **Development**
```bash
# Enter development shell
nix develop

# Build specific package
nix build .#package-name

# Run home-manager rebuild
home-manager switch --flake ".#cerberus"
```

## Documentation

### SillyTavern
- [Deployment Guide](docs/sillytavern/deployment-guide.md) - Complete setup instructions
- [Development Guide](docs/sillytavern/dev-guide.md) - Development and customization
- [Implementation Summary](docs/sillytavern/implementation-summary.md) - Technical details
- [Infrastructure Architecture](docs/sillytavern/infrastructure-architecture.md) - System design

### Module Development
- Each module in `modules/` is self-contained and documented
- Use `modules/sillytavern.nix` as a reference for new service modules
- Follow the established patterns for options and configuration

## Configuration Options

### SillyTavern Module
```nix
services.sillytavern-container = {
  enable = true;
  port = 8765;                    # Default port
  dataDir = "/var/lib/sillytavern";
  hostAddress = "127.0.0.1";      # Bind address
  openFirewall = false;           # Don't open to public
  enableMultiUser = false;        # Multi-user mode
  useContainer = true;            # Use Podman container
  imageTag = "latest";            # Docker image tag
};
```

### **Global Variables**
Edit `vars.nix` for system-wide settings:
- Monitor configuration
- Network settings
- User preferences
- Theme colors

## 🏷️ **Version Tags**

- `v1.0.0-sillytavern-working` - Stable SillyTavern deployment
- Previous tags contain historical configurations

## 🤝 **Contributing**

### **For Contributors**
1. Fork the repository
2. Create a feature branch
3. Make changes following existing patterns
4. Test with `nixos-rebuild dry-build`
5. Submit a pull request

### **For Downstream Packagers**
- All modules are self-contained and reusable
- Configuration options are clearly documented
- Dependencies are properly declared
- No hardcoded paths or values

## 📋 **Requirements**

- **NixOS**: 25.11 or later
- **Hardware**: NVIDIA GPU recommended (for Hyprland)
- **Memory**: 16GB+ recommended for development
- **Storage**: SSD recommended for performance

## 🔐 **Security**

- **Secrets**: Managed with agenix
- **Services**: Run as dedicated users
- **Network**: Firewall configured by default
- **Containers**: Rootless Podman with proper isolation

## 🐛 **Troubleshooting**

### **Common Issues**
1. **SillyTavern access denied**: Check whitelist configuration
2. **Build failures**: Run `nix flake update` and retry
3. **Service not starting**: Check journalctl for errors
4. **Hyprland crashes**: Verify NVIDIA drivers are loaded

### **Getting Help**
- Check service logs: `journalctl -u service-name`
- Verify configuration: `nixos-rebuild dry-build`
- Review module documentation in `modules/`

## 📄 **License**

This configuration is provided as-is for educational and personal use. Feel free to adapt and modify for your own needs.

---

**Last Updated**: 2025-10-31  
**NixOS Version**: 25.11.20251025.6a08e6b  
**SillyTavern**: v1.13.5 (container)
