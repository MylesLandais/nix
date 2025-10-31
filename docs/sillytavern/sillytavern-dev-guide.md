# SillyTavern Development Guide for NixOS

## Overview

This guide provides comprehensive instructions for developing, deploying, and managing SillyTavern on NixOS using Podman containers. It covers the complete workflow from initial setup to production deployment, with a focus on the declarative NixOS approach and data migration from legacy systems.

## Prerequisites

- NixOS installed and configured
- Basic familiarity with Nix language
- Access to existing SillyTavern data (if migrating)
- Understanding of container concepts

## Quick Start

### 1. Enable SillyTavern in Your Flake

Add the SillyTavern module to your `flake.nix`:

```nix
{
  inputs = {
    # ... existing inputs
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations.yourHost = nixpkgs.lib.nixosSystem {
      modules = [
        # ... existing modules
        ./modules/sillytavern.nix  # Add this line
        ({ config, ... }: {
          services.sillytavern = {
            enable = true;
            dataDir = "/var/lib/sillytavern";
            port = 8000;
            openFirewall = true;
          };
        })
      ];
    };
  };
}
```

### 2. Apply Configuration

```bash
sudo nixos-rebuild switch --flake .#yourHost
```

### 3. Access SillyTavern

Open your browser to `http://localhost:8000` (or your configured port).

## Architecture Overview

### Current Infrastructure

- **Production**: Unraid server with Docker (`smb://hydra/appdata/STConfig/Data`)
- **Legacy**: Arch Linux with Docker (`/run/media/warby/.../Workspace` - fuzzy "silly" match)
- **Next Gen**: NixOS with Podman (`/home/warby/appdata/silly/Data/default-user` → `/var/lib/sillytavern`)

### Container Configuration

```nix
services.sillytavern = {
  enable = true;
  dataDir = "/var/lib/sillytavern";  # Where data is stored
  port = 8000;                       # Port to listen on
  openFirewall = true;               # Allow external access
  useContainer = true;               # Use Podman container (default)
};
```

## Development Workflow

### Building the Package

1. **Get npmDepsHash**:
```bash
cd nix
nix build .#sillytavern 2>&1 | grep "got:" | head -1
```

2. **Update the hash** in `sillytavern.nix`:
```nix
npmDepsHash = "sha256-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
```

3. **Build again**:
```bash
nix build .#sillytavern
```

### Testing Container Locally

```bash
# Run container manually for testing
podman run -d \
  --name sillytavern-test \
  -p 8001:8000 \
  -v /tmp/silly-data:/home/node/app/data \
  ghcr.io/sillytavern/sillytavern:latest

# Check logs
podman logs sillytavern-test

# Stop test container
podman stop sillytavern-test && podman rm sillytavern-test
```

### Module Development

The SillyTavern module (`modules/sillytavern.nix`) supports two modes:

#### Container Mode (Recommended)
- Uses Podman for OCI container management
- Automatic image pulling and updates
- systemd service integration
- Rootless operation for security

#### Systemd Mode (Alternative)
- Direct systemd service running the Nix package
- Requires manual dependency management
- Less isolation but potentially better performance

## Data Management

### Directory Structure

SillyTavern stores data in this structure:

```
Data/default-user/
├── settings.json          # Core preferences
├── characters/            # Character definitions
├── chats/                 # Conversation histories
├── worlds/               # Lorebooks/world data
├── themes/               # UI themes
├── backgrounds/          # Background images
├── context/              # 40+ AI model configs
├── extensions/           # Third-party extensions
└── backups/              # Historical backups
```

### Migration Process

#### From Legacy Docker

1. **Backup existing data**:
```bash
# From legacy system
rsync -avh /path/to/silly/data/ /tmp/silly-backup/
```

2. **Transfer to NixOS**:
```bash
# On NixOS system
sudo mkdir -p /var/lib/sillytavern
sudo rsync -avh /tmp/silly-backup/ /var/lib/sillytavern/
sudo chown -R sillytavern:sillytavern /var/lib/sillytavern
```

3. **Restart service**:
```bash
sudo systemctl restart podman-sillytavern
```

#### From Production Unraid

1. **Access SMB share**:
```bash
sudo mount -t cifs //hydra/appdata /mnt/hydra -o credentials=/etc/samba/credentials
```

2. **Copy data**:
```bash
sudo rsync -avh /mnt/hydra/STConfig/Data/ /var/lib/sillytavern/data/
```

### Backup Strategy

```bash
# Create backup script
cat > /root/backup-sillytavern.sh << 'EOF'
#!/usr/bin/env bash
BACKUP_DIR="/backup/sillytavern"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p $BACKUP_DIR
rsync -avh --delete /var/lib/sillytavern/ $BACKUP_DIR/latest/
tar -czf $BACKUP_DIR/sillytavern-$DATE.tar.gz -C $BACKUP_DIR latest/

# Keep last 30 backups
ls -t $BACKUP_DIR/sillytavern-*.tar.gz | tail -n +31 | xargs rm -f
EOF

chmod +x /root/backup-sillytavern.sh

# Add to cron (daily at 3 AM)
echo "0 3 * * * /root/backup-sillytavern.sh" | sudo crontab -
```

## Configuration Options

### Basic Configuration

```nix
services.sillytavern = {
  enable = true;
  dataDir = "/var/lib/sillytavern";
  port = 8000;
  host = "0.0.0.0";        # Listen on all interfaces
  openFirewall = true;
  useContainer = true;
};
```

### Advanced Configuration

```nix
services.sillytavern = {
  # ... basic options
  extraOptions = [
    "--cap-drop=ALL"
    "--cap-add=CAP_NET_BIND_SERVICE"
    "--security-opt=no-new-privileges"
  ];
};
```

### Networking Configuration

```nix
# For reverse proxy setup
services.sillytavern = {
  host = "127.0.0.1";      # Only localhost access
  openFirewall = false;    # Let reverse proxy handle firewall
};

# Add Caddy reverse proxy
services.caddy = {
  enable = true;
  virtualHosts."silly.yourdomain.com" = {
    extraConfig = ''
      reverse_proxy localhost:8000
    '';
  };
};
```

## Troubleshooting

### Service Issues

```bash
# Check service status
sudo systemctl status podman-sillytavern

# View logs
sudo journalctl -u podman-sillytavern -f

# Check container status
podman ps | grep sillytavern

# View container logs
podman logs sillytavern
```

### Permission Issues

```bash
# Fix ownership
sudo chown -R sillytavern:sillytavern /var/lib/sillytavern

# Check current ownership
ls -la /var/lib/sillytavern
```

### Port Conflicts

```bash
# Check what's using port 8000
sudo ss -tlnp | grep 8000

# Change port in configuration
services.sillytavern.port = 8001;
```

### Data Issues

```bash
# Verify data integrity
find /var/lib/sillytavern -type f -exec sha256sum {} \; > data-checksum.txt

# Compare with backup
find /backup/sillytavern -type f -exec sha256sum {} \; > backup-checksum.txt
diff data-checksum.txt backup-checksum.txt
```

## Performance Tuning

### Container Resources

```nix
services.sillytavern = {
  # ... other config
  extraOptions = [
    "--memory=2g"
    "--cpus=1.0"
    "--pids-limit=1024"
  ];
};
```

### Storage Optimization

```bash
# Use faster storage for data directory
sudo mkdir -p /var/lib/sillytavern
sudo mount -t tmpfs -o size=1g tmpfs /var/lib/sillytavern  # For testing only

# For production, consider:
# - NVMe storage for data directory
# - ZFS/btrfs with compression
# - Regular defragmentation
```

## Security Considerations

### Container Hardening

- **Rootless operation**: Containers run as unprivileged user
- **Minimal capabilities**: Only necessary Linux capabilities granted
- **No new privileges**: Prevent privilege escalation
- **Read-only root filesystem**: Where possible

### Network Security

```nix
# Restrict to localhost only
services.sillytavern = {
  host = "127.0.0.1";
  openFirewall = false;
};

# Use firewall rules
networking.firewall = {
  allowedTCPPorts = [ 8000 ];
  allowedTCPPortRanges = [
    { from = 8000; to = 8000; }
  ];
};
```

### Data Protection

- **Regular backups**: Automated daily backups
- **Encryption**: Consider encrypting sensitive data
- **Access control**: Proper file permissions
- **Retention policy**: 7-year data retention as specified

## Integration Examples

### With Home Manager

```nix
# home.nix
{
  # Add SillyTavern to user packages for development
  home.packages = with pkgs; [
    # ... other packages
    (import ../sillytavern.nix { inherit (pkgs) lib buildNpmPackage fetchFromGitHub nodejs git; })
  ];
}
```

### With Agenix for Secrets

```nix
# For API keys or sensitive configuration
age.secrets.sillytavern-api-key = {
  file = ./secrets/sillytavern-api-key.age;
  owner = "sillytavern";
  group = "sillytavern";
};
```

## Contributing

### Code Style

- Follow Nixpkgs conventions
- Use `nixfmt` for formatting
- Add comments for complex logic
- Test changes before committing

### Testing

```bash
# Test module syntax
nix-instantiate --eval modules/sillytavern.nix

# Test flake
nix flake check

# Test build
nix build .#sillytavern
```

## Reference

### File Locations

- **Module**: `modules/sillytavern.nix`
- **Package**: `sillytavern.nix`
- **Configuration**: `hosts/cerberus/configuration.nix`
- **Documentation**: `infrastructure-architecture.md`

### Useful Commands

```bash
# Rebuild system
sudo nixos-rebuild switch --flake .#cerberus

# Update flake inputs
nix flake update

# Clean up old generations
sudo nix-collect-garbage -d

# Debug module
nix repl
:lf .
services.sillytavern.config
```

This guide provides a complete foundation for SillyTavern development and deployment on NixOS. For specific issues or advanced configurations, refer to the NixOS documentation and SillyTavern community resources.