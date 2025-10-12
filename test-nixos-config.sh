#!/usr/bin/env bash

# ============================================================================
# NixOS Configuration Testing Pipeline
# ============================================================================
#
# This script provides a comprehensive testing pipeline for NixOS configurations,
# including flake validation, dry-run builds, and basic system checks.
#
# Usage:
#   ./test-nixos-config.sh [host] [options]
#
# Arguments:
#   host    - Target host configuration (default: dell-potato)
#
# Options:
#   --dry-run     - Perform dry-run build only (no actual changes)
#   --flake-check - Run flake validation checks
#   --vm-test     - Build and test in QEMU VM (requires qemu)
#   --all         - Run all tests (default behavior)
#   --help        - Show this help message
#
# Examples:
#   ./test-nixos-config.sh                    # Test dell-potato with all checks
#   ./test-nixos-config.sh kraken --dry-run   # Dry-run test for kraken
#   ./test-nixos-config.sh --flake-check      # Only flake validation
#
# ============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
HOST="dell-potato"
DRY_RUN=false
FLAKE_CHECK=false
VM_TEST=false
ALL_TESTS=true

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

# Show usage information
show_help() {
    cat << EOF
NixOS Configuration Testing Pipeline

Usage: $0 [host] [options]

Arguments:
  host    Target host configuration (default: dell-potato)

Options:
  --dry-run     Perform dry-run build only (no actual changes)
  --flake-check Run flake validation checks only
  --vm-test     Build and test in QEMU VM (requires qemu)
  --all         Run all tests (default behavior)
  --help        Show this help message

Examples:
  $0                    # Test dell-potato with all checks
  $0 kraken --dry-run   # Dry-run test for kraken
  $0 --flake-check      # Only flake validation
EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                ALL_TESTS=false
                shift
                ;;
            --flake-check)
                FLAKE_CHECK=true
                ALL_TESTS=false
                shift
                ;;
            --vm-test)
                VM_TEST=true
                ALL_TESTS=false
                shift
                ;;
            --all)
                ALL_TESTS=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                HOST="$1"
                shift
                ;;
        esac
    done
}

# Check if required tools are available
check_dependencies() {
    local missing_tools=()

    if ! command -v nix &> /dev/null; then
        missing_tools+=("nix")
    fi

    if ! command -v git &> /dev/null; then
        missing_tools+=("git")
    fi

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        exit 1
    fi

    log_success "All required tools are available"
}

# Validate flake configuration
run_flake_check() {
    log_info "Running flake validation..."

    if nix flake check; then
        log_success "Flake validation passed"
        return 0
    else
        log_error "Flake validation failed"
        return 1
    fi
}

# Perform dry-run build
run_dry_run() {
    log_info "Performing dry-run build for host: $HOST"

    if sudo nixos-rebuild dry-run --flake ".#$HOST"; then
        log_success "Dry-run build successful"
        return 0
    else
        log_error "Dry-run build failed"
        return 1
    fi
}

# Build system configuration
run_build() {
    log_info "Building system configuration for host: $HOST"

    if sudo nixos-rebuild build --flake ".#$HOST"; then
        log_success "System build successful"
        return 0
    else
        log_error "System build failed"
        return 1
    fi
}

# Test in QEMU VM
run_vm_test() {
    log_info "Building VM test for host: $HOST"

    if nix build ".#nixosConfigurations.$HOST.config.system.build.vm"; then
        log_success "VM build successful"

        log_info "Starting VM test (press Ctrl+C to stop)..."
        if ./result/bin/run-*-vm; then
            log_success "VM test completed successfully"
            return 0
        else
            log_error "VM test failed"
            return 1
        fi
    else
        log_error "VM build failed"
        return 1
    fi
}

# Run all tests
run_all_tests() {
    local failed_tests=()

    log_info "Running complete test suite for host: $HOST"

    if ! run_flake_check; then
        failed_tests+=("flake-check")
    fi

    if ! run_dry_run; then
        failed_tests+=("dry-run")
    fi

    if ! run_build; then
        failed_tests+=("build")
    fi

    if [[ ${#failed_tests[@]} -eq 0 ]]; then
        log_success "All tests passed!"
        return 0
    else
        log_error "Failed tests: ${failed_tests[*]}"
        return 1
    fi
}

# Main execution
main() {
    parse_args "$@"
    check_dependencies

    log_info "Starting NixOS configuration testing pipeline"
    log_info "Target host: $HOST"

    local exit_code=0

    if [[ $ALL_TESTS == true ]]; then
        if ! run_all_tests; then
            exit_code=1
        fi
    else
        if [[ $FLAKE_CHECK == true ]]; then
            if ! run_flake_check; then
                exit_code=1
            fi
        fi

        if [[ $DRY_RUN == true ]]; then
            if ! run_dry_run; then
                exit_code=1
            fi
        fi

        if [[ $VM_TEST == true ]]; then
            if ! run_vm_test; then
                exit_code=1
            fi
        fi
    fi

    if [[ $exit_code -eq 0 ]]; then
        log_success "Testing pipeline completed successfully"
    else
        log_error "Testing pipeline completed with errors"
    fi

    exit $exit_code
}

# Run main function with all arguments
main "$@"