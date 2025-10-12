#!/usr/bin/env bash

# ============================================================================
# NixOS CI/CD Pipeline Script
# ============================================================================
#
# This script implements a CI/CD pipeline for NixOS configurations,
# suitable for integration with GitHub Actions, GitLab CI, or local automation.
#
# Features:
# - Automated flake validation
# - Configuration building and testing
# - System deployment (optional)
# - Rollback capabilities
# - Comprehensive logging and reporting
#
# Environment Variables:
#   DEPLOY_TARGET    - Target host for deployment (default: none)
#   DEPLOY_KEY       - SSH private key for deployment (optional)
#   ROLLBACK_ON_FAIL - Rollback on test failure (default: false)
#   VERBOSE          - Enable verbose output (default: false)
#
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default configuration
DEPLOY_TARGET="${DEPLOY_TARGET:-}"
DEPLOY_KEY="${DEPLOY_KEY:-}"
ROLLBACK_ON_FAIL="${ROLLBACK_ON_FAIL:-false}"
VERBOSE="${VERBOSE:-false}"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $1"
    fi
}

# Error handling
error_exit() {
    log_error "$1"
    exit 1
}

# Check if running in CI environment
is_ci() {
    [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${GITLAB_CI:-}" ]]
}

# Setup SSH for deployment
setup_ssh() {
    if [[ -n "$DEPLOY_KEY" ]]; then
        log_info "Setting up SSH for deployment..."

        mkdir -p ~/.ssh
        echo "$DEPLOY_KEY" | tr -d '\r' > ~/.ssh/deploy_key
        chmod 600 ~/.ssh/deploy_key

        # Add target host to known_hosts if provided
        if [[ -n "${DEPLOY_HOST:-}" ]]; then
            ssh-keyscan -H "$DEPLOY_HOST" >> ~/.ssh/known_hosts 2>/dev/null || true
        fi

        log_success "SSH setup completed"
    fi
}

# Validate flake
validate_flake() {
    log_info "Validating flake configuration..."

    if [[ "$VERBOSE" == "true" ]]; then
        nix flake check --verbose
    else
        nix flake check
    fi

    log_success "Flake validation passed"
}

# Build configuration
build_config() {
    local host="$1"
    log_info "Building configuration for host: $host"

    if [[ "$VERBOSE" == "true" ]]; then
        nix build ".#nixosConfigurations.$host.config.system.build.toplevel" --verbose
    else
        nix build ".#nixosConfigurations.$host.config.system.build.toplevel"
    fi

    log_success "Configuration build completed for $host"
}

# Test configuration with dry-run
test_config() {
    local host="$1"
    log_info "Testing configuration for host: $host (dry-run)"

    if [[ "$VERBOSE" == "true" ]]; then
        sudo nixos-rebuild dry-run --flake ".#$host" --verbose
    else
        sudo nixos-rebuild dry-run --flake ".#$host"
    fi

    log_success "Configuration test passed for $host"
}

# Deploy configuration
deploy_config() {
    local host="$1"
    local target="$2"

    if [[ -z "$target" ]]; then
        log_info "No deployment target specified, skipping deployment"
        return 0
    fi

    log_info "Deploying configuration to $target"

    if [[ -n "$DEPLOY_KEY" ]]; then
        # Remote deployment via SSH
        if [[ "$VERBOSE" == "true" ]]; then
            nixos-rebuild switch --flake ".#$host" --target-host "$target" --use-remote-sudo --verbose
        else
            nixos-rebuild switch --flake ".#$host" --target-host "$target" --use-remote-sudo
        fi
    else
        # Local deployment
        if [[ "$VERBOSE" == "true" ]]; then
            sudo nixos-rebuild switch --flake ".#$host" --verbose
        else
            sudo nixos-rebuild switch --flake ".#$host"
        fi
    fi

    log_success "Deployment completed successfully"
}

# Rollback on failure
rollback_config() {
    local host="$1"
    local target="$2"

    log_warning "Rolling back configuration for $host"

    if [[ -n "$target" && -n "$DEPLOY_KEY" ]]; then
        nixos-rebuild switch --rollback --target-host "$target" --use-remote-sudo
    else
        sudo nixos-rebuild switch --rollback
    fi

    log_success "Rollback completed"
}

# Generate test report
generate_report() {
    local host="$1"
    local status="$2"
    local report_file="nixos-test-report-${host}.txt"

    log_info "Generating test report: $report_file"

    {
        echo "NixOS Configuration Test Report"
        echo "================================"
        echo ""
        echo "Host: $host"
        echo "Timestamp: $(date -Iseconds)"
        echo "Status: $status"
        echo ""
        echo "System Information:"
        uname -a
        echo ""
        echo "Nix Version:"
        nix --version
        echo ""
        echo "Flake Inputs:"
        nix flake metadata --json | jq -r '.locks.nodes.root.inputs | to_entries[] | "\(.key): \(.value)"' 2>/dev/null || echo "jq not available"
        echo ""
        echo "Configuration Details:"
        nix eval ".#nixosConfigurations.$host.config.system.stateVersion" 2>/dev/null || echo "Could not evaluate stateVersion"
    } > "$report_file"

    log_success "Report generated: $report_file"
}

# Main CI pipeline
run_pipeline() {
    local host="$1"
    local status="PASSED"

    log_info "Starting NixOS CI/CD pipeline for host: $host"

    # Setup phase
    setup_ssh

    # Validation phase
    validate_flake

    # Build phase
    build_config "$host"

    # Test phase
    test_config "$host"

    # Deployment phase (only if target specified)
    if [[ -n "$DEPLOY_TARGET" ]]; then
        if ! deploy_config "$host" "$DEPLOY_TARGET"; then
            status="DEPLOY_FAILED"
            if [[ "$ROLLBACK_ON_FAIL" == "true" ]]; then
                rollback_config "$host" "$DEPLOY_TARGET"
            fi
        fi
    fi

    # Reporting phase
    generate_report "$host" "$status"

    if [[ "$status" == "PASSED" ]]; then
        log_success "Pipeline completed successfully"
    else
        error_exit "Pipeline completed with status: $status"
    fi
}

# Show usage
show_usage() {
    cat << EOF
NixOS CI/CD Pipeline

Usage: $0 <host> [options]

Arguments:
  host    Target NixOS configuration host

Environment Variables:
  DEPLOY_TARGET     Target host for deployment (default: none)
  DEPLOY_KEY        SSH private key for deployment (optional)
  DEPLOY_HOST       SSH host for known_hosts (optional)
  ROLLBACK_ON_FAIL  Rollback on deployment failure (default: false)
  VERBOSE           Enable verbose output (default: false)

Examples:
  $0 dell-potato                                    # Local testing only
  DEPLOY_TARGET=root@dell-potato $0 dell-potato     # Deploy to dell-potato
  VERBOSE=true $0 kraken                            # Verbose local testing
EOF
}

# Main execution
main() {
    if [[ $# -lt 1 ]]; then
        show_usage
        exit 1
    fi

    local host="$1"

    # Check if host configuration exists
    if ! nix eval ".#nixosConfigurations.$host" &>/dev/null; then
        error_exit "Host configuration '$host' not found in flake"
    fi

    run_pipeline "$host"
}

main "$@"