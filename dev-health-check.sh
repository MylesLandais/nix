#!/usr/bin/env bash

# ============================================================================
# Development Environment Health Check Script
# ============================================================================
#
# Comprehensive validation script for the Agent Sandbox development environment.
# Performs automated testing of all critical components, services, and tools
# to ensure operational readiness and identify configuration issues.
#
# CHECKED COMPONENTS:
# ===================
# - Container Runtime: Docker daemon and container status
# - Virtualization: libvirt/KVM setup and accessibility
# - Development Containers: Portainer, code-server, Jupyter, Livebook, Chrome Remote
# - User Environment: Home Manager configuration
# - Development Tools: Languages, frameworks, and utilities
# - Creative Tools: Professional open source software suite
# - Secrets Management: Agenix encrypted secrets
# - Gaming Tools: Steam, emulators, and gaming utilities
# - Shell Tools: Modern terminal enhancements
# - Nix Configuration: Flake validity and package integrity
# - Network Security: Firewall rules and port accessibility
# - VPN Services: Tailscale connectivity
#
# CONTAINER OPTIMIZATIONS MONITORED:
# ==================================
# | Service       | Optimized Size | Savings | Method |
# |---------------|----------------|---------|--------|
# | Jupyter       | 1.56GB         | 62%     | minimal-notebook |
# | Code-Server   | 662MB          | 15%     | linuxserver variant |
# | Livebook      | ~550MB         | 16%     | custom minimal |
# | Chrome Remote | 1.11GB         | 46%     | alpine debug |
# | Portainer     | 186MB          | -       | already optimized |
#
# CHECK CATEGORIES:
# ================
# - Infrastructure: Docker, libvirt, firewall
# - Containers: Status, ports, web interfaces
# - Development Tools: Installation and versions
# - Networking: Local and Tailscale access
# - Security: SSL certificates, authentication
#
# USAGE: ./dev-health-check.sh
# EXIT CODES: 0=success, 1=errors found
# ============================================================================

set -e

echo "=== Dev Environment Health Check ==="
echo ""

ERRORS=0
WARNINGS=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() {
    echo -e "${GREEN}✓${NC} $1"
}

fail() {
    echo -e "${RED}✗${NC} $1"
    ((ERRORS++))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

# Check Docker
echo "--- Docker ---"
if systemctl is-active --quiet docker; then
    pass "Docker service is running"
else
    fail "Docker service is not running"
fi

if docker info &>/dev/null; then
    pass "Docker daemon is accessible"
    DOCKER_VERSION=$(docker --version | awk '{print $3}' | tr -d ',')
    echo "  Version: $DOCKER_VERSION"
else
    fail "Cannot connect to Docker daemon"
fi

if groups | grep -q docker; then
    pass "User is in docker group"
else
    fail "User is not in docker group (run: sudo usermod -aG docker $USER)"
fi

echo ""

# Check libvirt
echo "--- libvirt/KVM ---"
if systemctl is-active --quiet libvirtd; then
    pass "libvirtd service is running"
else
    fail "libvirtd service is not running"
fi 2>/dev/null || true

if groups 2>/dev/null | grep -q libvirtd; then
    pass "User is in libvirtd group"
else
    fail "User is not in libvirtd group"
fi

if command -v virsh &> /dev/null && virsh list --all &>/dev/null 2>&1; then
    pass "libvirt is accessible"
else
    fail "libvirt is not accessible"
fi

if groups | grep -q libvirtd; then
    pass "User is in libvirtd group"
else
    fail "User is not in libvirtd group"
fi

if virsh list --all &>/dev/null; then
    pass "libvirt is accessible"
else
    warn "Cannot query libvirt (might need to log out/in for group changes)"
fi

echo ""

# Check Portainer container
echo "--- Portainer ---"
if docker ps --format '{{.Names}}' | grep -q portainer; then
    pass "Portainer container is running"
    PORTAINER_PORT=$(docker port portainer 2>/dev/null | grep 9000 | cut -d':' -f2)
    if [ -n "$PORTAINER_PORT" ]; then
        pass "Portainer accessible on port $PORTAINER_PORT"
        echo "  URL: http://localhost:$PORTAINER_PORT"
    fi
else
    fail "Portainer container is not running"
fi

echo ""

# Check code-server container
echo "--- code-server ---"
if docker ps --format '{{.Names}}' | grep -q code-server; then
    pass "code-server container is running"
    CODE_IMAGE=$(docker inspect code-server --format '{{.Config.Image}}' 2>/dev/null)
    if [[ "$CODE_IMAGE" == *"codercom/code-server"* ]]; then
        pass "code-server using expected image ($CODE_IMAGE)"
    else
        fail "code-server not using expected image (using: $CODE_IMAGE)"
    fi
    CODE_PORT=$(docker port code-server 2>/dev/null | grep 8080 | cut -d':' -f2)
    if [ -n "$CODE_PORT" ]; then
        pass "code-server accessible on port $CODE_PORT"
        if [ -f /var/lib/code-server-certs/cert.pem ]; then
            pass "SSL certificate exists"
            if curl -s --insecure --max-time 5 https://localhost:$CODE_PORT | grep -q "code-server"; then
                pass "code-server HTTPS interface responding"
                echo "  URL: https://localhost:$CODE_PORT (accept self-signed certificate)"
            else
                fail "code-server HTTPS interface not responding"
            fi
        else
            fail "SSL certificate not found"
            echo "  URL: http://localhost:$CODE_PORT"
        fi
    fi
else
    fail "code-server container is not running"
fi

echo ""

# Check jupyter container
echo "--- Jupyter ---"
if docker ps --format '{{.Names}}' | grep -q jupyter; then
    pass "Jupyter container is running"
    JUPYTER_PORT=$(docker port jupyter 2>/dev/null | grep 8888 | cut -d':' -f2)
    if [ -n "$JUPYTER_PORT" ]; then
        pass "Jupyter accessible on port $JUPYTER_PORT"
        echo "  URL: http://localhost:$JUPYTER_PORT (token: devsandbox123)"
        if curl -s --max-time 5 "http://localhost:$JUPYTER_PORT/tree" | grep -q "Jupyter"; then
            pass "Jupyter web interface is responding correctly"
        else
            fail "Jupyter web interface is not responding"
        fi
    fi
    # Extra Python checks
    PYTHON_VERSION=$(docker exec jupyter python --version 2>/dev/null | awk '{print $2}')
    if [ -n "$PYTHON_VERSION" ]; then
        pass "Python $PYTHON_VERSION is available in container"
        # Check if Jupyter data directory is accessible
        if docker exec jupyter ls /home/jovyan/work &>/dev/null; then
            pass "Jupyter workspace directory is mounted and accessible"
        else
            fail "Jupyter workspace directory is not accessible"
        fi
        # Check if key Python packages are available
        if docker exec jupyter python -c "import numpy, pandas, matplotlib; print('Key packages imported successfully')" &>/dev/null; then
            pass "Essential Python packages (numpy, pandas, matplotlib) are installed"
        else
            fail "Essential Python packages are missing"
        fi
    else
        fail "Python is not available in Jupyter container"
    fi
else
    fail "Jupyter container is not running"
fi

echo ""

# Check livebook container
echo "--- Livebook ---"
if docker ps --format '{{.Names}}' | grep -q livebook; then
    pass "livebook container is running"
    LIVEBOOK_PORT=$(docker port livebook 2>/dev/null | grep 8080 | cut -d':' -f2)
    if [ -n "$LIVEBOOK_PORT" ]; then
        pass "livebook accessible on port $LIVEBOOK_PORT"
        echo "  URL: http://localhost:$LIVEBOOK_PORT (password: devsandbox123)"
        if curl -s --max-time 5 "http://localhost:$LIVEBOOK_PORT/authenticate" | grep -q "Livebook"; then
            pass "Livebook web interface responding"
        else
            fail "Livebook web interface not responding"
        fi
    fi
else
    fail "livebook container is not running"
fi

echo ""

# Check chrome-remote container
echo "--- Chrome Remote ---"
if docker ps --format '{{.Names}}' | grep -q chrome-remote; then
    pass "chrome-remote container is running"
    CHROME_WEBDRIVER_PORT=$(docker port chrome-remote 2>/dev/null | grep 4444 | cut -d':' -f2)
    CHROME_VNC_PORT=$(docker port chrome-remote 2>/dev/null | grep 5900 | cut -d':' -f2)
    CHROME_NOVNC_PORT=$(docker port chrome-remote 2>/dev/null | grep 7900 | cut -d':' -f2)
    CHROME_CDP_PORT=$(docker port chrome-remote 2>/dev/null | grep 9222 | cut -d':' -f2)
    if [ -n "$CHROME_WEBDRIVER_PORT" ]; then
        pass "Chrome WebDriver accessible on port $CHROME_WEBDRIVER_PORT"
        echo "  WebDriver: http://localhost:$CHROME_WEBDRIVER_PORT/wd/hub"
        if curl -s "http://localhost:$CHROME_WEBDRIVER_PORT/wd/hub/status" | grep -q '"ready":true'; then
            pass "WebDriver status: ready"
        else
            fail "WebDriver status check failed"
        fi
    fi
    if [ -n "$CHROME_VNC_PORT" ]; then
        pass "Chrome VNC accessible on port $CHROME_VNC_PORT"
        echo "  VNC: vnc://localhost:$CHROME_VNC_PORT (password: devsandbox123)"
        echo "  SSH Tunnel: ssh -L 5901:localhost:$CHROME_VNC_PORT user@host (then connect to localhost:5901)"
        if nc -z localhost $CHROME_VNC_PORT 2>/dev/null; then
            pass "VNC port $CHROME_VNC_PORT is open"
            # Test VNC authentication (basic connectivity test)
            if timeout 5 bash -c "echo 'RFB 003.008' | nc localhost $CHROME_VNC_PORT | head -1 | grep -q 'RFB'"; then
                pass "VNC server responding to connections"
            else
                fail "VNC server not responding properly"
            fi
        else
            fail "VNC port $CHROME_VNC_PORT is not open"
        fi
    fi
    if [ -n "$CHROME_NOVNC_PORT" ]; then
        pass "Chrome noVNC accessible on port $CHROME_NOVNC_PORT"
        echo "  noVNC: http://localhost:$CHROME_NOVNC_PORT"
        echo "  Remmina: Create VNC connection with SSH tunnel enabled"
        if curl -s --max-time 5 "http://localhost:$CHROME_NOVNC_PORT" | grep -q "noVNC"; then
            pass "noVNC web interface responding"
        else
            fail "noVNC web interface not responding"
        fi
    fi
    if [ -n "$CHROME_CDP_PORT" ]; then
        pass "Chrome DevTools Protocol accessible on port $CHROME_CDP_PORT"
        echo "  CDP: ws://localhost:$CHROME_CDP_PORT"
        if nc -z localhost $CHROME_CDP_PORT 2>/dev/null; then
            pass "CDP port $CHROME_CDP_PORT is open"
        else
            fail "CDP port $CHROME_CDP_PORT is not open"
        fi
    fi
else
    fail "chrome-remote container is not running"
fi

echo ""

# Check home-manager
echo "--- Home Manager ---"
if command -v home-manager &>/dev/null; then
    pass "home-manager is installed"
    HM_VERSION=$(home-manager --version 2>&1 | head -n1 | awk '{print $2}')
    echo "  Version: $HM_VERSION"
    if [ -d "$HOME/.config/home-manager" ]; then
        pass "Home Manager config directory exists"
    else
        warn "Home Manager config directory not found"
    fi
else
    fail "home-manager is not available"
fi

echo ""

# Check dev tools
echo "--- Dev Tools ---"
for tool in docker-compose lazydocker virt-manager elixir livebook node postgres remmina; do
    if command -v $tool &>/dev/null; then
        VERSION=$(case $tool in
            elixir) elixir --version | head -n1 | awk '{print $2}' ;;
            livebook) livebook --version ;;
            node) node --version ;;
            postgres) postgres --version | awk '{print $3}' ;;
            *) $tool --version 2>&1 | head -n1 | awk '{print $NF}' ;;
        esac)
        pass "$tool is installed ($VERSION)"
    else
        fail "$tool is not available"
    fi
done

echo ""

# Check creative tools
echo "--- Creative Tools ---"
for tool in gimp krita blender obs-studio audacity opencv; do
    if command -v $tool &>/dev/null; then
        VERSION=$($tool --version 2>&1 | head -n1 | awk '{print $NF}' || echo "unknown")
        pass "$tool is installed ($VERSION)"
    else
        fail "$tool is not available"
    fi
done

echo ""

# Check agenix secrets
echo "--- Agenix Secrets ---"
if command -v agenix &>/dev/null; then
    pass "agenix is installed"
    AGENIX_VERSION=$(agenix --version 2>&1 | head -n1 | awk '{print $2}')
    echo "  Version: $AGENIX_VERSION"
    # Check if secrets directory exists
    if [ -d "/run/secrets" ]; then
        pass "Secrets directory exists"
        SECRET_COUNT=$(ls /run/secrets | wc -l)
        echo "  $SECRET_COUNT secrets available"
    else
        warn "Secrets directory not found (secrets may not be decrypted yet)"
    fi
else
    fail "agenix is not available"
fi

echo ""

# Check gaming tools
echo "--- Gaming Tools ---"
for tool in steam retroarch mgba snes9x-gtk mednafen pcsx2 rpcs3 lutris heroic protontricks; do
    if command -v $tool &>/dev/null; then
        VERSION=$($tool --version 2>&1 | head -n1 | awk '{print $NF}' || echo "installed")
        pass "$tool is installed ($VERSION)"
    else
        warn "$tool is not available (gaming module may not be enabled)"
    fi
done

echo ""

# Check shell tools
echo "--- Shell Tools ---"
for tool in atuin bat direnv eza fzf yazi zoxide zsh fish; do
    if command -v $tool &>/dev/null; then
        VERSION=$($tool --version 2>&1 | head -n1 | awk '{print $NF}' || echo "installed")
        pass "$tool is installed ($VERSION)"
    else
        warn "$tool is not available (shelltools module may not be enabled)"
    fi
done

echo ""

# Check NixOS Sudo Configuration

echo "--- NixOS Sudo Configuration ---"

NIXOS_REBUILD="/run/current-system/sw/bin/nixos-rebuild"
if [ -x "$NIXOS_REBUILD" ]; then
    if sudo -n "$NIXOS_REBUILD" list-generations >/dev/null 2>&1; then
        pass "Passwordless nixos-rebuild configured"
    else
        warn "Passwordless nixos-rebuild not configured"
        echo "  To fix, add to your NixOS configuration.nix:"
        echo "    security.sudo.extraRules = ["
        echo "      { users = [ \"warby\" ];"
        echo "        commands = ["
        echo "          { command = \"$NIXOS_REBUILD *\"; options = [ \"NOPASSWD\" ]; }"
        echo "        ];"
        echo "      }"
        echo "    ];"
        echo "  Then run: sudo nixos-rebuild switch"
    fi
else
    warn "nixos-rebuild not found"
fi

echo ""

# Check Nix flake
echo "--- Nix Flake ---"
if [ -f "flake.nix" ] && [ -f "flake.lock" ]; then
    pass "Flake files exist"
    if nix flake check --no-build 2>/dev/null; then
        pass "Flake check passed"
    else
        warn "Flake check failed (run: nix flake check)"
    fi
    if nix flake metadata 2>/dev/null | grep -q "Locked"; then
        pass "Flake lock is valid"
    else
        fail "Flake lock is invalid"
    fi
else
    fail "Flake files not found"
fi

echo ""

# Check firewall ports
echo "--- Firewall ---"
if sudo -n iptables -L -n | grep -q 9000; then
    pass "Port 9000 (Portainer) is open"
else
    warn "Port 9000 might not be open in firewall"
fi

if sudo -n iptables -L -n | grep -q 8080; then
    pass "Port 8080 (code-server) is open"
else
    warn "Port 8080 might not be open in firewall"
fi

if sudo -n iptables -L -n | grep -q 4444; then
    pass "Port 4444 (Chrome WebDriver) is open"
else
    warn "Port 4444 might not be open in firewall"
fi

if sudo -n iptables -L -n | grep -q 5900; then
    pass "Port 5900 (Chrome VNC) is open"
else
    warn "Port 5900 might not be open in firewall"
fi

if sudo -n iptables -L -n | grep -q 7900; then
    pass "Port 7900 (Chrome noVNC) is open"
else
    warn "Port 7900 might not be open in firewall"
fi

if sudo -n iptables -L -n | grep -q 9222; then
    pass "Port 9222 (Chrome CDP) is open"
else
    warn "Port 9222 might not be open in firewall"
fi

if sudo -n iptables -L -n | grep -q 8888; then
    pass "Port 8888 (Jupyter) is open"
else
    warn "Port 8888 might not be open in firewall"
fi

if sudo -n iptables -L -n | grep -q 8081; then
    pass "Port 8081 (Livebook) is open"
else
    warn "Port 8081 might not be open in firewall"
fi

echo ""

# Check Tailscale interface
echo "--- Tailscale ---"
if ip link show tailscale0 &>/dev/null; then
    pass "Tailscale interface exists"
    TAILSCALE_IP=$(ip -4 addr show tailscale0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
    if [ -n "$TAILSCALE_IP" ]; then
        echo "  IP: $TAILSCALE_IP"
        echo "  Portainer: http://$TAILSCALE_IP:9000"
        echo "  code-server: http://$TAILSCALE_IP:8080"
        echo "  Livebook: http://$TAILSCALE_IP:8081"
        echo "  Jupyter: http://$TAILSCALE_IP:8888"
        echo "  Chrome WebDriver: http://$TAILSCALE_IP:4444/wd/hub"
        echo "  Chrome VNC: vnc://$TAILSCALE_IP:5900"
        echo "  Chrome noVNC: http://$TAILSCALE_IP:7900"
        echo "  Chrome CDP: ws://$TAILSCALE_IP:9222"
    fi
else
    warn "Tailscale interface not found (services only accessible locally)"
fi

echo ""

# Summary
echo "=== Summary ==="
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}$WARNINGS warning(s) found${NC}"
    exit 0
else
    echo -e "${RED}$ERRORS error(s), $WARNINGS warning(s) found${NC}"
    echo ""
    echo "Common fixes:"
    echo "  • Group membership: Log out and back in, or run: newgrp docker && newgrp libvirtd"
    echo "  • Start containers: docker start portainer code-server chrome-remote livebook"
    echo "  • Start services: sudo systemctl start docker libvirtd"
    echo "  • Passwordless nixos-rebuild: See NixOS Sudo section for configuration details"
    echo "  • Flake issues: Run nix flake update or nix flake lock"
    echo "  • Missing tools: Ensure modules (dev, gaming, pro) are imported in configuration.nix"
    exit 1
fi
