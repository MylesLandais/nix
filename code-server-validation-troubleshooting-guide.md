# Code Server Validation and Troubleshooting Guide

This guide provides comprehensive instructions for validating, troubleshooting, and optimizing your code-server setup on NixOS with Podman.

## Table of Contents
1. [Initial Setup Validation](#initial-setup-validation)
2. [Common Issues and Solutions](#common-issues-and-solutions)
3. [Container Status and Monitoring](#container-status-and-monitoring)
4. [Network Connectivity Troubleshooting](#network-connectivity-troubleshooting)
5. [Performance Optimization](#performance-optimization)
6. [Security Considerations](#security-considerations)
7. [Feedback and Issue Reporting](#feedback-and-issue-reporting)

---

## Initial Setup Validation

Follow these steps to verify your code-server setup is working correctly:

### 1. Verify Configuration Application

```bash
# Check if the latest configuration was applied
sudo nixos-rebuild switch --dry-run
```

### 2. Validate Container Status

```bash
# Check if the code-server container is running
sudo podman ps | grep code-server

# If not running, check all containers including stopped ones
sudo podman ps -a | grep code-server
```

Expected output should show:
- Container name: `code-server`
- Status: `Up` (with duration)
- Port mapping: `0.0.0.0:8080->8080/tcp`

### 3. Verify Port Accessibility

```bash
# Check if port 8080 is listening
sudo ss -tlnp | grep 8080

# Alternative using netstat
sudo netstat -tlnp | grep 8080
```

### 4. Test Web Interface Access

1. Open a web browser and navigate to: `http://<your-server-ip>:8080`
2. You should see the code-server login screen
3. Login with the configured password (default: `devsandbox123`)
4. Verify your workspace is accessible at `/home/coder/Workspace`

### 5. Validate Workspace Mount

```bash
# Check if workspace directory exists on host
ls -la ~/Workspace

# Check if workspace is accessible inside container
sudo podman exec -it code-server ls -la /home/coder/Workspace

# Verify file permissions match
stat ~/Workspace
sudo podman exec -it code-server stat /home/coder/Workspace
```

### 6. Check Container Logs for Errors

```bash
# View recent container logs
sudo podman logs --tail 50 code-server

# Follow logs in real-time
sudo podman logs -f code-server
```

---

## Common Issues and Solutions

### Issue 1: Container Fails to Start

**Symptoms:**
- Container shows as `Exited` or `Restarting`
- Web interface inaccessible

**Troubleshooting Steps:**

1. Check container logs for specific errors:
   ```bash
   sudo podman logs code-server
   ```

2. Verify the image was pulled correctly:
   ```bash
   sudo podman images | grep code-server
   ```

3. Manually pull the latest image if needed:
   ```bash
   sudo podman pull linuxserver/code-server:latest
   ```

4. Check if port 8080 is already in use:
   ```bash
   sudo ss -tlnp | grep 8080
   ```

5. Try starting the container manually:
   ```bash
   sudo podman start code-server
   ```

### Issue 2: Cannot Access Web Interface

**Symptoms:**
- Container is running but web interface unreachable
- Connection timeout or connection refused errors

**Troubleshooting Steps:**

1. Verify firewall rules:
   ```bash
   sudo nixos-rebuild switch
   sudo iptables -L -n | grep 8080
   ```

2. Check if service is listening on correct interface:
   ```bash
   sudo ss -tlnp | grep 8080
   ```
   Should show `0.0.0.0:8080` (not `127.0.0.1:8080`)

3. Test local connectivity:
   ```bash
   curl -I http://localhost:8080
   ```

4. Check if SELinux or AppArmor is blocking access:
   ```bash
   # For SELinux
   sudo ausearch -m avc -ts recent
   
   # For AppArmor
   sudo aa-status
   ```

### Issue 3: Workspace Files Not Visible

**Symptoms:**
- Empty workspace in code-server
- File operations fail
- Permission denied errors

**Troubleshooting Steps:**

1. Verify host directory exists and has content:
   ```bash
   ls -la ~/Workspace
   ```

2. Check mount permissions:
   ```bash
   sudo podman exec -it code-server ls -la /home/coder/Workspace
   ```

3. Verify user ID mapping:
   ```bash
   # Host user ID
   id warby
   
   # Container user ID
   sudo podman exec -it code-server id
   ```

4. Fix permissions if needed:
   ```bash
   sudo chown -R 1000:1000 ~/Workspace
   sudo chmod -R 755 ~/Workspace
   ```

### Issue 4: Performance Issues

**Symptoms:**
- Slow file operations
- Laggy interface
- High resource usage

**Troubleshooting Steps:**

1. Check resource usage:
   ```bash
   # Container resource usage
   sudo podman stats code-server
   
   # System resources
   htop
   df -h
   ```

2. Check for I/O bottlenecks:
   ```bash
   iotop
   ```

3. Verify available disk space:
   ```bash
   df -h ~/Workspace
   ```

---

## Container Status and Monitoring

### Basic Container Commands

```bash
# List running containers
sudo podman ps

# List all containers (including stopped)
sudo podman ps -a

# View detailed container information
sudo podman inspect code-server

# View real-time resource usage
sudo podman stats code-server

# View container logs
sudo podman logs code-server

# Follow logs in real-time
sudo podman logs -f code-server

# Execute commands inside container
sudo podman exec -it code-server /bin/bash
```

### Health Checks

```bash
# Check if code-server process is running inside container
sudo podman exec -it code-server ps aux | grep code-server

# Test internal connectivity
sudo podman exec -it code-server curl -I http://localhost:8080

# Check disk usage inside container
sudo podman exec -it code-server df -h
```

### Automated Monitoring Script

Create a monitoring script at `~/scripts/code-server-monitor.sh`:

```bash
#!/bin/bash

# Code Server Health Monitor
CONTAINER_NAME="code-server"
PORT="8080"

echo "=== Code Server Health Check ==="
echo "Timestamp: $(date)"
echo

# Check container status
echo "1. Container Status:"
sudo podman ps -a --filter name=$CONTAINER_NAME --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo

# Check port listening
echo "2. Port Status:"
sudo ss -tlnp | grep $PORT || echo "Port $PORT not found listening"
echo

# Check resource usage
echo "3. Resource Usage:"
sudo podman stats --no-stream $CONTAINER_NAME --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
echo

# Check recent logs for errors
echo "4. Recent Errors (last 10 lines):"
sudo podman logs --tail 10 $CONTAINER_NAME 2>&1 | grep -i error || echo "No errors found"
echo

# Check disk space
echo "5. Disk Space:"
df -h ~/Workspace
echo

echo "=== Health Check Complete ==="
```

Make it executable:
```bash
chmod +x ~/scripts/code-server-monitor.sh
```

---

## Network Connectivity Troubleshooting

### Basic Network Checks

```bash
# Check if port is open and listening
sudo ss -tlnp | grep 8080

# Check firewall rules
sudo iptables -L -n | grep 8080
sudo nft list ruleset | grep 8080

# Test local connectivity
curl -I http://localhost:8080

# Test remote connectivity (from another machine)
curl -I http://<server-ip>:8080
```

### Advanced Network Diagnostics

```bash
# Check network interfaces
ip addr show

# Check routing table
ip route show

# Check for network conflicts
sudo netstat -tulpn | grep 8080

# Trace network path
traceroute <server-ip>

# Check DNS resolution
nslookup <server-ip>
```

### Firewall Configuration

```bash
# Check current firewall rules
sudo nixos-rebuild switch --dry-run | grep firewall

# Add port if missing (temporary)
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT

# Make permanent by updating configuration
# Edit modules/dev.nix to ensure port is in allowedTCPPorts
```

### SSL/TLS Configuration (if needed)

If you decide to add SSL/TLS later:

```bash
# Generate self-signed certificate
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/code-server.key \
  -out /etc/ssl/certs/code-server.crt

# Update container configuration to use SSL
# Add volume mounts for certificates
# Update environment variables for SSL
```

---

## Performance Optimization

### Resource Allocation

1. **CPU and Memory Limits** (add to modules/dev.nix):

```nix
virtualisation.oci-containers.containers."code-server" = {
  # ... existing configuration ...
  extraOptions = [
    "--memory=2g"
    "--cpus=2"
  ];
};
```

2. **Storage Optimization**:

```bash
# Clean up unused containers and images
sudo podman system prune -a

# Monitor disk usage
sudo podman system df

# Use tmpfs for temporary files
# Add to container configuration:
extraOptions = [
  "--tmpfs /tmp"
];
```

### File System Performance

1. **Use Directories with Good Performance**:
   - Avoid network-mounted directories for workspace
   - Use SSD storage if available
   - Consider using a dedicated partition for workspace

2. **Optimize Volume Mounts**:

```nix
volumes = [
  "/home/warby/Workspace:/home/coder/Workspace:rw,Z"
  # Add :Z for SELinux compatibility if needed
  # Consider :cached for better performance on some systems
];
```

### Network Performance

1. **Use Host Networking** (if security permits):

```nix
virtualisation.oci-containers.containers."code-server" = {
  # ... existing configuration ...
  extraOptions = [
    "--network=host"
  ];
  # Remove ports mapping when using host networking
};
```

2. **Optimize for Remote Access**:

```bash
# Enable compression for SSH tunneling
ssh -C -L 8080:localhost:8080 user@server

# Use SSH multiplexing
ssh -M -S ~/.ssh/code-server.sock user@server
```

### VS Code Performance Settings

Create `~/.config/Code/User/settings.json`:

```json
{
  "files.watcherExclude": {
    "**/node_modules/**": true,
    "**/.git/**": true,
    "**/dist/**": true
  },
  "search.exclude": {
    "**/node_modules": true,
    "**/dist": true,
    "**/.git": true
  },
  "typescript.preferences.includePackageJsonAutoImports": "off",
  "extensions.autoUpdate": false,
  "telemetry.enableTelemetry": false,
  "extensions.ignoreRecommendations": true
}
```

---

## Security Considerations

### Basic Security Measures

1. **Change Default Password**:

```nix
# In modules/dev.nix
dev.containers.codeServer.password = "your-secure-password";
```

2. **Use HTTPS** (recommended for production):

```nix
# Add SSL certificate configuration
virtualisation.oci-containers.containers."code-server" = {
  volumes = [
    "/home/warby/Workspace:/home/coder/Workspace"
    "/etc/ssl/certs/code-server.crt:/config/certs/code-server.crt:ro"
    "/etc/ssl/private/code-server.key:/config/certs/code-server.key:ro"
  ];
  environment = {
    # ... existing environment variables ...
    HTTPS_ENABLED = "true";
  };
};
```

3. **Network Security**:

```bash
# Restrict access to specific IP ranges
sudo iptables -A INPUT -p tcp --dport 8080 -s 192.168.1.0/24 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8080 -j DROP
```

### Advanced Security

1. **Use Reverse Proxy**:

```nix
# Example Nginx configuration
services.nginx = {
  enable = true;
  virtualHosts."code-server.example.com" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://localhost:8080";
      proxyWebsockets = true;
    };
  };
};
```

2. **Container Security**:

```nix
virtualisation.oci-containers.containers."code-server" = {
  # ... existing configuration ...
  extraOptions = [
    "--read-only"  # Make container filesystem read-only
    "--tmpfs /tmp" # Use tmpfs for temporary files
    "--no-new-privileges"  # Prevent privilege escalation
    "--cap-drop=ALL"  # Drop all capabilities
    "--cap-add=CHOWN"  # Add only needed capabilities
    "--cap-add=SETUID"
    "--cap-add=SETGID"
  ];
};
```

3. **User Isolation**:

```bash
# Create dedicated user for code-server
sudo useradd -r -s /bin/false codeserver

# Update container to run as non-root user
# Add to container configuration:
user = "1000:1000"  # Match your user ID
```

### Access Control

1. **SSH Tunneling** (recommended for remote access):

```bash
# Create SSH tunnel
ssh -L 8080:localhost:8080 user@server

# Access via local browser
http://localhost:8080
```

2. **VPN Access**:

```bash
# Configure WireGuard or OpenVPN
# Only allow access from VPN clients
sudo iptables -A INPUT -p tcp --dport 8080 -s 10.0.0.0/24 -j ACCEPT
```

---

## Feedback and Issue Reporting

### Collecting Diagnostic Information

Create a diagnostic script at `~/scripts/code-server-diagnostics.sh`:

```bash
#!/bin/bash

# Code Server Diagnostic Information Collector
REPORT_FILE="code-server-diagnostics-$(date +%Y%m%d-%H%M%S).txt"

echo "=== Code Server Diagnostic Report ===" > $REPORT_FILE
echo "Generated: $(date)" >> $REPORT_FILE
echo "Hostname: $(hostname)" >> $REPORT_FILE
echo "OS Version: $(nixos-version)" >> $REPORT_FILE
echo >> $REPORT_FILE

echo "=== Container Information ===" >> $REPORT_FILE
sudo podman ps -a --filter name=code-server >> $REPORT_FILE 2>&1
echo >> $REPORT_FILE

echo "=== Container Configuration ===" >> $REPORT_FILE
sudo podman inspect code-server >> $REPORT_FILE 2>&1
echo >> $REPORT_FILE

echo "=== Container Logs (last 50 lines) ===" >> $REPORT_FILE
sudo podman logs --tail 50 code-server >> $REPORT_FILE 2>&1
echo >> $REPORT_FILE

echo "=== Network Configuration ===" >> $REPORT_FILE
ip addr show >> $REPORT_FILE 2>&1
sudo ss -tlnp | grep 8080 >> $REPORT_FILE 2>&1
echo >> $REPORT_FILE

echo "=== Firewall Rules ===" >> $REPORT_FILE
sudo iptables -L -n | grep 8080 >> $REPORT_FILE 2>&1
echo >> $REPORT_FILE

echo "=== System Resources ===" >> $REPORT_FILE
free -h >> $REPORT_FILE 2>&1
df -h >> $REPORT_FILE 2>&1
echo >> $REPORT_FILE

echo "=== NixOS Configuration ===" >> $REPORT_FILE
grep -A 20 "oci-containers" /etc/nixos/configuration.nix >> $REPORT_FILE 2>&1
echo >> $REPORT_FILE

echo "=== Diagnostic Complete ===" >> $REPORT_FILE
echo "Report saved to: $REPORT_FILE"
```

Make it executable:
```bash
chmod +x ~/scripts/code-server-diagnostics.sh
```

### Reporting Issues

When reporting issues, include:

1. **System Information**:
   - NixOS version
   - Kernel version
   - Hardware details

2. **Configuration Details**:
   - Relevant parts of your NixOS configuration
   - Any custom modifications

3. **Error Messages**:
   - Complete error messages
   - Container logs
   - System logs

4. **Steps to Reproduce**:
   - Clear steps to reproduce the issue
   - Expected vs actual behavior

### Where to Report

1. **Local Issues** (configuration, setup):
   - Create an issue in your project repository
   - Include diagnostic report from the script above

2. **Code Server Issues** (application bugs):
   - Report to the code-server GitHub repository
   - Include version information from container

3. **NixOS Issues** (system-level):
   - Report to the NixOS issue tracker
   - Include system configuration details

### Getting Help

1. **Check Logs First**:
   ```bash
   sudo podman logs code-server
   sudo journalctl -u podman
   ```

2. **Verify Configuration**:
   ```bash
   sudo nixos-rebuild switch --dry-run
   ```

3. **Test with Minimal Configuration**:
   - Temporarily simplify your configuration
   - Add components back incrementally

4. **Community Resources**:
   - NixOS Discourse forum
   - NixOS Matrix/IRC channels
   - code-server documentation

---

## Quick Reference Commands

### Essential Commands
```bash
# Start/stop/restart container
sudo podman start code-server
sudo podman stop code-server
sudo podman restart code-server

# View logs
sudo podman logs -f code-server

# Execute in container
sudo podman exec -it code-server /bin/bash

# Rebuild configuration
sudo nixos-rebuild switch

# Check container status
sudo podman ps -a | grep code-server

# Check port
sudo ss -tlnp | grep 8080
```

### Emergency Commands
```bash
# Force stop container
sudo podman kill code-server

# Remove container (will be recreated by NixOS)
sudo podman rm code-server

# Reset to clean state
sudo podman system prune -a
sudo nixos-rebuild switch
```

---

This guide should help you validate, troubleshoot, and optimize your code-server setup. For additional help, run the diagnostic script and include its output when reporting issues.