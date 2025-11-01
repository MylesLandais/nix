# Code Server Quick Reference Guide

This guide provides essential commands and quick troubleshooting steps for code-server on NixOS with Podman.

## Essential Commands

### Container Management
```bash
# Start/stop/restart container
sudo podman start code-server
sudo podman stop code-server
sudo podman restart code-server

# Check container status
sudo podman ps -a | grep code-server

# View container logs
sudo podman logs -f code-server

# Execute commands inside container
sudo podman exec -it code-server /bin/bash

# Remove container (will be recreated by NixOS)
sudo podman rm code-server
```

### System Management
```bash
# Rebuild NixOS configuration
sudo nixos-rebuild switch

# Check configuration before applying
sudo nixos-rebuild switch --dry-run

# Clean up unused containers and images
sudo podman system prune -a
```

### Network Checks
```bash
# Check if port is listening
sudo ss -tlnp | grep 8080

# Test local connectivity
curl -I http://localhost:8080

# Check firewall rules
sudo iptables -L -n | grep 8080
```

## Quick Troubleshooting

### Container Won't Start
```bash
# Check logs for errors
sudo podman logs code-server

# Verify image exists
sudo podman images | grep code-server

# Pull latest image if needed
sudo podman pull linuxserver/code-server:latest

# Start manually
sudo podman start code-server
```

### Can't Access Web Interface
```bash
# Check if port is open
sudo ss -tlnp | grep 8080

# Test local access
curl -I http://localhost:8080

# Check firewall
sudo nixos-rebuild switch

# Find your IP address
ip addr show | grep 'inet '
```

### Workspace Issues
```bash
# Check workspace directory
ls -la ~/Workspace

# Check permissions
stat ~/Workspace

# Fix permissions if needed
sudo chown -R 1000:1000 ~/Workspace
sudo chmod -R 755 ~/Workspace

# Check mount inside container
sudo podman exec -it code-server ls -la /home/coder/Workspace
```

## Monitoring Scripts

### Health Monitor
```bash
# Run comprehensive health check
./scripts/code-server-monitor.sh

# Check specific components
sudo podman stats code-server
sudo podman exec code-server ps aux
```

### Diagnostic Collection
```bash
# Collect diagnostic information
./scripts/code-server-diagnostics.sh

# View recent logs
sudo podman logs --tail 50 code-server

# Follow logs in real-time
sudo podman logs -f code-server
```

## Configuration

### Change Password
Edit `modules/dev.nix`:
```nix
dev.containers.codeServer.password = "your-new-password";
```

Then rebuild:
```bash
sudo nixos-rebuild switch
```

### Change Port
Edit `modules/dev.nix`:
```nix
dev.containers.codeServer.port = 9080;
```

Then rebuild:
```bash
sudo nixos-rebuild switch
```

## Security

### SSH Tunneling (Recommended for Remote Access)
```bash
# Create SSH tunnel
ssh -L 8080:localhost:8080 user@server

# Access via local browser
http://localhost:8080
```

### Basic Security
```bash
# Change default password immediately
# Use HTTPS in production environments
# Consider VPN access for additional security
# Regularly update container image
```

## Performance

### Resource Monitoring
```bash
# Check container resource usage
sudo podman stats code-server

# Check system resources
htop
df -h
free -h
```

### Optimization Tips
- Use SSD storage for workspace
- Avoid network-mounted directories
- Limit container resources if needed
- Clean up unused containers and images

## Emergency Recovery

### Full Reset
```bash
# Stop and remove container
sudo podman stop code-server
sudo podman rm code-server

# Clean up system
sudo podman system prune -a

# Rebuild from configuration
sudo nixos-rebuild switch
```

### Configuration Issues
```bash
# Check configuration syntax
sudo nixos-rebuild switch --dry-run

# View current configuration
cat /etc/nixos/configuration.nix
cat /etc/nixos/modules/dev.nix

# Check system logs
sudo journalctl -xe
```

## Getting Help

### Collect Information Before Asking
```bash
# Run diagnostic script
./scripts/code-server-diagnostics.sh

# Collect basic info
sudo podman ps -a | grep code-server
sudo podman logs --tail 20 code-server
sudo ss -tlnp | grep 8080
```

### Common Issues to Check
1. Container status and logs
2. Port accessibility and firewall rules
3. Workspace directory permissions
4. Available disk space
5. System resource usage

### Where to Get Help
- NixOS documentation: https://nixos.org/manual/nixos/stable/
- Code Server documentation: https://github.com/coder/code-server
- NixOS Discourse: https://discourse.nixos.org/
- NixOS Matrix/IRC channels

## URLs and Access

### Default Configuration
- URL: `http://<server-ip>:8080`
- Password: `devsandbox123`
- Workspace: `/home/coder/Workspace` (mapped to `~/Workspace`)

### After Configuration Changes
- URL: `http://<server-ip>:<configured-port>`
- Password: `<configured-password>`
- Workspace: `/home/coder/Workspace`

---

**Remember**: Always check the diagnostic script output before reporting issues, and include relevant logs and configuration details when asking for help.