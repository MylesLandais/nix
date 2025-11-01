#!/bin/bash

# Code Server Health Monitor
CONTAINER_NAME="code-server"
PORT="8080"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored status
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

echo "======================================"
echo "Code Server Health Check"
echo "Timestamp: $(date)"
echo "======================================"
echo

# Check if container exists
if ! sudo podman ps -a --format "{{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
    print_status "ERROR" "Container '${CONTAINER_NAME}' not found"
    echo "Run 'sudo nixos-rebuild switch' to create the container"
    exit 1
fi

# 1. Container Status
echo "1. Container Status:"
container_info=$(sudo podman ps -a --filter name=$CONTAINER_NAME --format "{{.Status}}")
if echo "$container_info" | grep -q "Up"; then
    print_status "OK" "Container is running: $container_info"
else
    print_status "ERROR" "Container is not running: $container_info"
    echo "Try: sudo podman start $CONTAINER_NAME"
fi
echo

# 2. Port Status
echo "2. Port Status:"
port_info=$(sudo ss -tlnp 2>/dev/null | grep ":$PORT ")
if [ -n "$port_info" ]; then
    print_status "OK" "Port $PORT is listening:"
    echo "$port_info"
else
    print_status "ERROR" "Port $PORT is not listening"
    echo "Check firewall rules and container configuration"
fi
echo

# 3. Resource Usage
echo "3. Resource Usage:"
if sudo podman stats --no-stream $CONTAINER_NAME --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null; then
    echo
else
    print_status "WARN" "Could not retrieve resource usage (container might not be running)"
fi
echo

# 4. Recent Logs for Errors
echo "4. Recent Errors (last 10 lines):"
error_logs=$(sudo podman logs --tail 10 $CONTAINER_NAME 2>&1 | grep -i error)
if [ -n "$error_logs" ]; then
    print_status "WARN" "Errors found in logs:"
    echo "$error_logs"
else
    print_status "OK" "No errors found in recent logs"
fi
echo

# 5. Disk Space
echo "5. Disk Space:"
workspace_path="$HOME/Workspace"
if [ -d "$workspace_path" ]; then
    disk_usage=$(df -h "$workspace_path" 2>/dev/null | tail -1)
    if [ -n "$disk_usage" ]; then
        echo "$disk_usage"
        usage_percent=$(echo "$disk_usage" | awk '{print $5}' | sed 's/%//')
        if [ "$usage_percent" -gt 90 ]; then
            print_status "WARN" "Disk usage is high (${usage_percent}%)"
        else
            print_status "OK" "Disk usage is normal (${usage_percent}%)"
        fi
    else
        print_status "ERROR" "Could not check disk space for $workspace_path"
    fi
else
    print_status "ERROR" "Workspace directory $workspace_path does not exist"
fi
echo

# 6. Container Health Check
echo "6. Container Health Check:"
if sudo podman exec $CONTAINER_NAME curl -s http://localhost:$PORT > /dev/null 2>&1; then
    print_status "OK" "Code server is responding internally"
else
    print_status "ERROR" "Code server is not responding internally"
fi
echo

# 7. External Connectivity Check
echo "7. External Connectivity Check:"
server_ip=$(ip route get 1.1.1.1 | awk '{print $7; exit}' 2>/dev/null)
if [ -n "$server_ip" ]; then
    if curl -s --connect-timeout 5 http://$server_ip:$PORT > /dev/null 2>&1; then
        print_status "OK" "Code server is accessible externally at http://$server_ip:$PORT"
    else
        print_status "WARN" "Code server is not accessible externally at http://$server_ip:$PORT"
        echo "This could be due to firewall rules or network configuration"
    fi
else
    print_status "WARN" "Could not determine server IP address"
fi
echo

echo "======================================"
echo "Health Check Complete"
echo "======================================"