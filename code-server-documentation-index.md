# Code Server Documentation Index

This page serves as a central hub for all code-server documentation and resources in this NixOS setup.

## Documentation Files

### Setup and Configuration
- **[Simplified Code Server Setup](simplified-code-server-setup.md)** - Basic configuration for running code-server with Podman
- **[Code Server Connection Guide](code-server-connection-guide.md)** - Quick start guide for accessing code-server

### Validation and Troubleshooting
- **[Comprehensive Validation and Troubleshooting Guide](code-server-validation-troubleshooting-guide.md)** - Detailed guide for validating setup and resolving issues
- **[Quick Reference Guide](code-server-quick-reference.md)** - Essential commands and quick troubleshooting steps

### Scripts and Tools
- **[Health Monitor Script](scripts/code-server-monitor.sh)** - Automated health checking for code-server
- **[Diagnostic Collection Script](scripts/code-server-diagnostics.sh)** - Comprehensive diagnostic information collector

## Quick Start

1. **First-time Setup**: Follow the [Simplified Code Server Setup](simplified-code-server-setup.md)
2. **Access Code Server**: Use the [Connection Guide](code-server-connection-guide.md)
3. **Validate Setup**: Run the health monitor script:
   ```bash
   ./scripts/code-server-monitor.sh
   ```

## Common Tasks

### I Need to Troubleshoot an Issue
1. Run the health monitor: `./scripts/code-server-monitor.sh`
2. If issues persist, collect diagnostics: `./scripts/code-server-diagnostics.sh`
3. Follow the [Comprehensive Troubleshooting Guide](code-server-validation-troubleshooting-guide.md)

### I Need Quick Commands
- Check the [Quick Reference Guide](code-server-quick-reference.md) for essential commands
- Use the health monitor script for status checks

### I Want to Change Configuration
1. Edit `modules/dev.nix` as needed
2. Rebuild: `sudo nixos-rebuild switch`
3. Validate with: `./scripts/code-server-monitor.sh`

## Documentation Structure

```
code-server-documentation/
├── Setup & Configuration
│   ├── simplified-code-server-setup.md
│   └── code-server-connection-guide.md
├── Validation & Troubleshooting
│   ├── code-server-validation-troubleshooting-guide.md
│   └── code-server-quick-reference.md
└── Scripts & Tools
    ├── scripts/code-server-monitor.sh
    └── scripts/code-server-diagnostics.sh
```

## Configuration Files

The main configuration is located in:
- **Primary Configuration**: [`modules/dev.nix`](modules/dev.nix)
- **Host Configuration**: [`hosts/cerberus/configuration.nix`](hosts/cerberus/configuration.nix)

## Key Concepts

### Container Management
- Uses Podman for container management
- Container is managed by NixOS OCI containers module
- Automatically starts on system boot

### Network Configuration
- Default port: 8080
- HTTP access (HTTPS can be configured)
- Firewall rules automatically configured

### Storage
- Workspace directory: `~/Workspace` (host) → `/home/coder/Workspace` (container)
- User ID mapping: 1000:1000
- Persistent storage through volume mounts

## Security Considerations

### Default Security
- HTTP access (consider HTTPS for production)
- Default password: `devsandbox123` (change immediately)
- Container runs as non-root user

### Recommended Enhancements
- Change default password
- Implement HTTPS/TLS
- Use SSH tunneling for remote access
- Consider VPN access for additional security

## Performance Optimization

### Resource Management
- Monitor with: `sudo podman stats code-server`
- Adjust container resources in configuration if needed
- Use SSD storage for workspace

### Network Performance
- Consider host networking for better performance
- Use SSH tunneling for secure remote access
- Optimize for your network environment

## Getting Help

### Self-Service
1. Run diagnostic script: `./scripts/code-server-diagnostics.sh`
2. Check [Troubleshooting Guide](code-server-validation-troubleshooting-guide.md)
3. Review [Quick Reference](code-server-quick-reference.md) for common commands

### Community Resources
- NixOS Documentation: https://nixos.org/manual/nixos/stable/
- Code Server Documentation: https://github.com/coder/code-server
- NixOS Discourse: https://discourse.nixos.org/

### Reporting Issues
When reporting issues, include:
1. Diagnostic script output
2. Relevant configuration sections
3. Complete error messages
4. Steps to reproduce

## Version Information

- **NixOS**: Check with `nixos-version`
- **Code Server Image**: `linuxserver/code-server:latest`
- **Podman**: Check with `sudo podman version`

## Maintenance

### Regular Tasks
- Update container image: `sudo podman pull linuxserver/code-server:latest`
- Clean up unused resources: `sudo podman system prune -a`
- Monitor disk usage: `df -h`

### Backup Considerations
- Backup workspace directory: `~/Workspace`
- Export container configuration: `sudo podman export code-server`
- Document any custom configuration changes

---

**Tip**: Bookmark this page as your central hub for all code-server related documentation and resources.