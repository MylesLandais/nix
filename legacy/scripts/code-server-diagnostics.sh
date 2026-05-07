#!/bin/bash

# Code Server Diagnostic Information Collector
# This script collects comprehensive diagnostic information for troubleshooting

REPORT_DIR="$HOME/diagnostics"
mkdir -p "$REPORT_DIR"
REPORT_FILE="$REPORT_DIR/code-server-diagnostics-$(date +%Y%m%d-%H%M%S).txt"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    local status=$1
    local message=$2
    
    case $status in
        "OK")
            echo -e "${GREEN}[OK]${NC} $message"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message"
            ;;
        *)
            echo "[INFO] $message"
            ;;
    esac
}

# Function to append section to report
append_section() {
    local section_name=$1
    local command=$2
    
    echo "======================================" >> "$REPORT_FILE"
    echo "$section_name" >> "$REPORT_FILE"
    echo "======================================" >> "$REPORT_FILE"
    echo "Generated: $(date)" >> "$REPORT_FILE"
    echo >> "$REPORT_FILE"
    
    if eval "$command" >> "$REPORT_FILE" 2>&1; then
        print_status "OK" "Collected: $section_name"
    else
        print_status "WARN" "Failed to collect: $section_name"
        echo "Command failed: $command" >> "$REPORT_FILE"
    fi
    
    echo >> "$REPORT_FILE"
}

echo "======================================"
echo "Code Server Diagnostic Collection"
echo "======================================"
echo

# Start collecting diagnostic information
{
    echo "Code Server Diagnostic Report"
    echo "Generated: $(date)"
    echo "Hostname: $(hostname)"
    echo "User: $(whoami)"
    echo "OS Version: $(nixos-version)"
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime)"
    echo
} > "$REPORT_FILE"

print_status "OK" "Starting diagnostic collection..."
print_status "INFO" "Report will be saved to: $REPORT_FILE"

# System Information
append_section "System Information" "uname -a"
append_section "NixOS Version" "nixos-version"
append_section "System Load" "uptime"
append_section "Memory Usage" "free -h"
append_section "Disk Usage" "df -h"
append_section "Mounted Filesystems" "mount | column -t"

# Container Information
append_section "Podman Version" "sudo podman version"
append_section "Podman Info" "sudo podman info"
append_section "Running Containers" "sudo podman ps"
append_section "All Containers" "sudo podman ps -a"
append_section "Container Images" "sudo podman images"
append_section "Code Server Container Details" "sudo podman inspect code-server"
append_section "Code Server Container Logs (last 100 lines)" "sudo podman logs --tail 100 code-server"

# Network Information
append_section "Network Interfaces" "ip addr show"
append_section "Routing Table" "ip route show"
append_section "Port 8080 Status" "sudo ss -tlnp | grep 8080"
append_section "Firewall Rules (iptables)" "sudo iptables -L -n"
append_section "Network Connections" "sudo netstat -tuln"

# Process Information
append_section "Running Processes" "ps aux"
append_section "Podman Processes" "ps aux | grep podman"

# Configuration Files
append_section "NixOS Configuration (relevant sections)" "grep -A 20 -B 5 'oci-containers\|code-server\|podman' /etc/nixos/configuration.nix"
append_section "Dev Module Configuration" "cat /etc/nixos/modules/dev.nix 2>/dev/null || echo 'File not found'"
append_section "Host Configuration" "grep -A 10 -B 5 'dev\|code-server' /etc/nixos/hosts/*/configuration.nix"

# Workspace Information
append_section "Workspace Directory Status" "ls -la ~/Workspace"
append_section "Workspace Permissions" "stat ~/Workspace"
append_section "Workspace Disk Usage" "du -sh ~/Workspace/* 2>/dev/null | head -20"

# System Logs
append_section "System Journal (recent)" "sudo journalctl --since '1 hour ago' --no-pager"
append_section "Podman Journal (recent)" "sudo journalctl -u podman --since '1 hour ago' --no-pager"

# Security Information
append_section "SELinux Status" "sestatus 2>/dev/null || echo 'SELinux not available'"
append_section "AppArmor Status" "sudo aa-status 2>/dev/null || echo 'AppArmor not available'"
append_section "User Groups" "groups"
append_section "Sudo Rules" "sudo -l"

# Performance Information
append_section "Container Resource Usage" "sudo podman stats --no-stream code-server"
append_section "I/O Statistics" "iostat -x 1 1 2>/dev/null || echo 'iostat not available'"
append_section "CPU Information" "lscpu"

# Create a summary section
{
    echo "======================================"
    echo "Diagnostic Summary"
    echo "======================================"
    echo "Report generated: $(date)"
    echo "System: $(hostname) ($(nixos-version))"
    echo
    
    # Check container status
    if sudo podman ps --format "{{.Names}}" | grep -q "^code-server$"; then
        echo "✓ Code-server container is running"
    else
        echo "✗ Code-server container is not running"
    fi
    
    # Check port status
    if sudo ss -tlnp 2>/dev/null | grep -q ":8080 "; then
        echo "✓ Port 8080 is listening"
    else
        echo "✗ Port 8080 is not listening"
    fi
    
    # Check workspace
    if [ -d "$HOME/Workspace" ]; then
        echo "✓ Workspace directory exists"
    else
        echo "✗ Workspace directory does not exist"
    fi
    
    echo
    echo "Common issues to check:"
    echo "1. Container logs for error messages"
    echo "2. Firewall rules blocking port 8080"
    echo "3. Workspace directory permissions"
    echo "4. Available disk space"
    echo "5. System resource usage"
    echo
    echo "Next steps:"
    echo "1. Review this report for error messages"
    echo "2. Check the 'Code Server Container Logs' section"
    echo "3. Verify network configuration in 'Network Information'"
    echo "4. Run 'sudo nixos-rebuild switch' if configuration issues found"
    echo
} >> "$REPORT_FILE"

# Compress the report if it's large
if [ $(stat -f%z "$REPORT_FILE" 2>/dev/null || stat -c%s "$REPORT_FILE") -gt 1048576 ]; then
    gzip "$REPORT_FILE"
    REPORT_FILE="${REPORT_FILE}.gz"
    print_status "INFO" "Report compressed: $REPORT_FILE"
else
    print_status "OK" "Report created: $REPORT_FILE"
fi

echo
echo "======================================"
echo "Diagnostic Collection Complete"
echo "======================================"
echo
echo "Report saved to: $REPORT_FILE"
echo
echo "To share this report:"
echo "1. Upload the report file to a file sharing service"
echo "2. Include the report in your issue description"
echo "3. Highlight any error messages you find in the report"
echo
echo "Quick commands to check common issues:"
echo "- View container logs: sudo podman logs code-server"
echo "- Check container status: sudo podman ps -a | grep code-server"
echo "- Test web interface: curl -I http://localhost:8080"
echo "- Rebuild configuration: sudo nixos-rebuild switch"