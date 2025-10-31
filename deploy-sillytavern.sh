#!/usr/bin/env bash

# SillyTavern Deployment Script for NixOS
# This script deploys and verifies SillyTavern with multi-user support using Podman containers

set -e

echo "=== SillyTavern NixOS Deployment Script ==="
echo

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root for certain operations
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_warning "Running as root. Some commands will use sudo where needed."
    fi
}

# Navigate to NixOS config directory
navigate_to_config() {
    print_status "Navigating to NixOS configuration directory..."
    cd ~/nix || { print_error "Could not find ~/nix directory. Please run from your home directory."; exit 1; }
}

# Test configuration build
test_config() {
    print_status "Testing NixOS configuration build..."
    if nix flake check; then
        print_status "Configuration check passed!"
    else
        print_error "Configuration check failed!"
        print_warning "Note: If you're getting unfree package errors (e.g., NVIDIA drivers),"
        print_warning "      you may need to run: export NIXPKGS_ALLOW_UNFREE=1"
        exit 1
    fi
}

# Deploy configuration
deploy_config() {
    print_status "Deploying NixOS configuration..."
    if sudo nixos-rebuild switch --flake ".#cerberus"; then
        print_status "Configuration deployed successfully!"
    else
        print_error "Configuration deployment failed!"
        print_warning "Note: If you're getting unfree package errors, make sure your"
        print_warning "      configuration.nix has: nixpkgs.config.allowUnfree = true;"
        exit 1
    fi
}

# Verify service status
verify_service() {
    print_status "Verifying SillyTavern service status..."
    
    # Check systemd service
    if systemctl is-active --quiet podman-sillytavern.service; then
        print_status "✓ Systemd service is running"
    else
        print_error "✗ Systemd service is not running"
        return 1
    fi
    
    # Check container
    if podman ps --format "table {{.Names}}\t{{.Status}}" | grep -q "sillytavern.*Up"; then
        print_status "✓ Podman container is running"
    else
        print_error "✗ Podman container is not running"
        return 1
    fi
    
    # Check port
    if ss -tlnp | grep -q ":8000"; then
        print_status "✓ Service is listening on port 8000"
    else
        print_error "✗ Service is not listening on port 8000"
        return 1
    fi
}

# Show service information
show_service_info() {
    print_status "Service Information:"
    echo "----------------------------------------"
    echo "Service: podman-sillytavern.service"
    echo "Container: sillytavern"
    echo "Port: 8000"
    echo "Data directory: /var/lib/sillytavern"
    echo
    echo "Access URLs:"
    echo "  Local: http://localhost:8000"
    echo "  Network: http://$(hostname -I | awk '{print $1}'):8000"
    echo
    echo "Useful commands:"
    echo "  View logs: sudo journalctl -u podman-sillytavern.service -f"
    echo "  Container stats: podman stats sillytavern"
    echo "  Restart service: sudo systemctl restart podman-sillytavern.service"
    echo
}

# Show next steps
show_next_steps() {
    print_status "Next Steps:"
    echo "----------------------------------------"
    echo "1. Open SillyTavern in your browser"
    echo "2. Click 'Account' in the top navigation"
    echo "3. Click 'Create New Account'"
    echo "4. Enter username and password"
    echo "5. Login with credentials"
    echo
    echo "Each user gets isolated data in /var/lib/sillytavern/data/<username>/"
    echo
    print_status "Deployment completed successfully!"
}

# Main execution
main() {
    check_root
    navigate_to_config
    
    # Ask for confirmation before proceeding
    echo "This script will deploy SillyTavern with multi-user support."
    echo "The service will be accessible from your network on port 8000."
    echo
    read -p "Do you want to continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Deployment cancelled."
        exit 0
    fi
    
    test_config
    deploy_config
    
    # Wait a moment for service to start
    print_status "Waiting for service to start..."
    sleep 10
    
    if verify_service; then
        show_service_info
        show_next_steps
    else
        print_error "Service verification failed. Check the logs:"
        echo "  sudo journalctl -u podman-sillytavern.service -n 50"
        exit 1
    fi
}

# Run main function
main "$@"