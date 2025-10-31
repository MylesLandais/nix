# SillyTavern NixOS Deployment Guide

## Overview

This guide provides step-by-step instructions for deploying SillyTavern with multi-user support using Podman containers on NixOS.

## Prerequisites

- NixOS system with flake-based configuration
- Podman support (automatically enabled by the module)
- Network access for multiple users (1-30 concurrent users)

## Deployment Steps

### Step 1: Verify Configuration

The SillyTavern module has been updated with the following configuration in `hosts/cerberus/configuration.nix`:

```nix
services.sillytavern-container = {
  enable = true;
  hostAddress = "0.0.0.0";  # Allow network access for multiple users
  port = 8000;
  enableMultiUser = true;    # Enable user account management
  openFirewall = true;       # Open firewall for external access
  useContainer = true;       # Use Podman container
  imageTag = "latest";       # Consider pinning digest for production
};
```

### Step 2: Test Configuration Build

```bash
# Navigate to your NixOS config directory
cd ~/nix

# Validate the configuration
nix flake check

# Test build without applying
# Note: The configuration now includes nixpkgs.config.allowUnfree = true
# to handle unfree packages like NVIDIA drivers
sudo nixos-rebuild test --flake ".#cerberus"
```

### Step 3: Deploy Configuration

```bash
# Apply the configuration
sudo nixos-rebuild switch --flake ".#cerberus"

# Verify service status
systemctl status podman-sillytavern.service
```

### Step 4: Verify Container Status

```bash
# Check if container is running
podman ps -a | grep sillytavern

# Check container logs
podman logs sillytavern

# Verify container health
podman inspect sillytavern | grep Health
```

### Step 5: Access SillyTavern

- **Local access**: http://localhost:8000
- **Network access**: http://<your-ip-address>:8000

### Step 6: Create Test Users

1. Open SillyTavern in your browser
2. Click "Account" in the top navigation
3. Click "Create New Account"
4. Enter username and password
5. Login with credentials

Each user gets isolated data in `/var/lib/sillytavern/data/<username>/`

## Verification Testing

### Basic Functionality

- [ ] User registration works
- [ ] User login/logout works
- [ ] Multiple concurrent users can login
- [ ] User data is isolated
- [ ] Sessions persist after browser restart
- [ ] Service survives system reboot

### Performance Monitoring

```bash
# Watch service logs
sudo journalctl -u podman-sillytavern.service -f

# Check container stats
podman stats sillytavern

# Monitor system resources
htop
```

### Expected Resource Usage

| Users | RAM Usage | CPU Load |
|-------|-----------|----------|
| 1-5   | 200-500MB | <5%      |
| 5-15  | 500MB-1GB | 5-15%    |
| 15-30 | 1-2GB     | 15-30%   |

## Maintenance Commands

### Service Management

```bash
# View logs
sudo journalctl -u podman-sillytavern.service -f

# Restart service
sudo systemctl restart podman-sillytavern.service

# Stop service
sudo systemctl stop podman-sillytavern.service

# View container status
podman ps -a | grep sillytavern
```

### Updates

```bash
# Pull latest image
sudo podman pull ghcr.io/sillytavern/sillytavern:latest

# Restart service to apply update
sudo systemctl restart podman-sillytavern.service
```

### Backups

```bash
# Create backup
sudo tar czf sillytavern-backup-$(date +%Y%m%d).tar.gz /var/lib/sillytavern/data

# Restore backup (if needed)
sudo systemctl stop podman-sillytavern.service
sudo tar xzf sillytavern-backup-YYYYMMDD.tar.gz -C /
sudo chown -R sillytavern:sillytavern /var/lib/sillytavern
sudo systemctl start podman-sillytavern.service
```

## Important File Locations

- **Data directory**: `/var/lib/sillytavern`
- **Config file**: `/var/lib/sillytavern/config/config.yaml`
- **User data**: `/var/lib/sillytavern/data/<username>/`
- **Service logs**: `sudo journalctl -u podman-sillytavern.service`

## Troubleshooting

### Users Can't Login

```bash
# Verify multi-user enabled
sudo cat /var/lib/sillytavern/config/config.yaml | grep enableUserAccounts

# Check service logs
sudo journalctl -u podman-sillytavern.service -f
```

### Service Won't Start

```bash
# Check for port conflicts
sudo ss -tlnp | grep 8000

# Check container logs
podman logs sillytavern

# Verify image pulled
podman images | grep sillytavern
```

### Slow Performance

```bash
# Check container resources
podman stats sillytavern

# Check disk space
df -h /var/lib/sillytavern
```

## Security Considerations

1. **Network Access**: The service is configured to accept connections from any IP (0.0.0.0)
2. **User Isolation**: Each user's data is stored in separate directories
3. **Firewall**: Port 8000 is open in the firewall
4. **Container Security**: Running as non-root user with limited resources

## Optional Enhancements

### Add HTTPS with nginx

Add to your configuration:

```nix
services.nginx = {
  enable = true;
  recommendedProxySettings = true;
  recommendedTlsSettings = true;
  
  virtualHosts."sillytavern.local" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:8000";
      proxyWebsockets = true;
    };
  };
};

# Update SillyTavern config to localhost only
services.sillytavern.hostAddress = "127.0.0.1";
services.sillytavern.openFirewall = false;
```

### Add Automated Backups

Add to your configuration:

```nix
services.restic.backups.sillytavern = {
  paths = [ "/var/lib/sillytavern/data" ];
  repository = "/backup/sillytavern";
  passwordFile = "/etc/nixos/secrets/restic-password";
  timerConfig = {
    OnCalendar = "daily";
    Persistent = true;
  };
  pruneOpts = [
    "--keep-daily 7"
    "--keep-weekly 4"
    "--keep-monthly 6"
  ];
};
```

## Production Considerations

1. **Image Pinning**: Consider pinning the container image digest for production
2. **Resource Limits**: Adjust memory and CPU limits based on actual usage
3. **Monitoring**: Set up monitoring for service health and resource usage
4. **Backup Strategy**: Implement regular automated backups
5. **HTTPS**: Use reverse proxy with HTTPS for production deployments

## Migration to Native Service

When nixpkgs issue #455581 is resolved:

1. Test native service in VM environment
2. Backup container data: `sudo tar czf backup.tar.gz /var/lib/sillytavern/`
3. Switch module configuration to native service
4. Rebuild: `sudo nixos-rebuild switch`
5. Verify data migration and user access
6. Keep backup until native service is stable

Track issue status: https://github.com/nixos/nixpkgs/issues/455581