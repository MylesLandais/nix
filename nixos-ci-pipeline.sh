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

# Resiliency and monitoring configuration
STATE_FILE="${STATE_FILE:-.nixos-build-state}"
LOG_FILE="${LOG_FILE:-nixos-build-$(date +%Y%m%d-%H%M%S).log}"
MONITOR_INTERVAL="${MONITOR_INTERVAL:-30}"
RESUME_BUILD="${RESUME_BUILD:-false}"

# Logging functions
log_info() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[INFO]${NC} [$timestamp] $1" | tee -a "$LOG_FILE"
}

log_success() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[SUCCESS]${NC} [$timestamp] $1" | tee -a "$LOG_FILE"
}

log_warning() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARNING]${NC} [$timestamp] $1" | tee -a "$LOG_FILE"
}

log_error() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR]${NC} [$timestamp] $1" | tee -a "$LOG_FILE"
}

log_verbose() {
    if [[ "$VERBOSE" == "true" ]]; then
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        echo -e "${BLUE}[VERBOSE]${NC} [$timestamp] $1" | tee -a "$LOG_FILE"
    fi
}

# Enhanced error handling with context
error_exit() {
    local error_msg="$1"
    local exit_code="${2:-1}"

    # Capture system state on error
    log_system_state "ERROR_CONTEXT"

    log_error "$error_msg"
    save_build_state "FAILED" "$error_msg"
    exit "$exit_code"
}

# Signal handling for graceful shutdown
cleanup_on_exit() {
    local signal="$1"
    log_warning "Received signal $signal, performing graceful shutdown..."

    # Save current state
    save_build_state "INTERRUPTED" "Signal $signal received"

    # Log final system state
    log_system_state "INTERRUPTION_CONTEXT"

    # Clean up any temporary files if needed
    [[ -f "$STATE_FILE.tmp" ]] && rm -f "$STATE_FILE.tmp"

    log_info "Shutdown complete. Build state saved to $STATE_FILE"
    exit 130  # Standard exit code for SIGINT
}

# Set up signal traps
setup_signal_traps() {
    trap 'cleanup_on_exit SIGINT' SIGINT
    trap 'cleanup_on_exit SIGTERM' SIGTERM
    trap 'cleanup_on_exit SIGHUP' SIGHUP
    log_verbose "Signal traps configured for SIGINT, SIGTERM, SIGHUP"
}

# Check if running in CI environment
is_ci() {
    [[ -n "${CI:-}" ]] || [[ -n "${GITHUB_ACTIONS:-}" ]] || [[ -n "${GITLAB_CI:-}" ]]
}

# System monitoring functions
log_system_state() {
    local context="${1:-GENERAL}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    {
        echo "=== SYSTEM STATE [$context] - $timestamp ==="
        echo "Load Average: $(uptime | awk -F'load average:' '{ print $2 }')"
        echo "Memory Usage: $(free -h | grep '^Mem:' | awk '{print $3 "/" $2 " (" int($3/$2*100) "%)"}')"
        echo "Disk Usage (/): $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 ")"}')"
        echo "CPU Temperature: $(sensors 2>/dev/null | grep -E 'Core|Package' | head -1 || echo 'N/A')"
        echo "Active Nix Processes: $(pgrep -f nix | wc -l)"
        echo "Build Directory Size: $(du -sh /tmp/nix-build-* 2>/dev/null | awk '{sum += $1} END {print sum ? sum : "0"}' || echo '0')"
        echo "========================================"
        echo ""
    } >> "$LOG_FILE"
}

# Background monitoring function
start_monitoring() {
    local host="$1"
    local pid_file="/tmp/nixos-monitor-$$.pid"

    # Start background monitoring
    (
        echo $$ > "$pid_file"
        log_verbose "Starting system monitoring (interval: ${MONITOR_INTERVAL}s)"

        while true; do
            log_system_state "MONITORING"
            sleep "$MONITOR_INTERVAL"
        done
    ) &
    MONITOR_PID=$!

    # Clean up pid file on exit
    trap "rm -f '$pid_file'; kill $MONITOR_PID 2>/dev/null" EXIT

    log_verbose "Monitoring started with PID $MONITOR_PID"
}

stop_monitoring() {
    if [[ -n "${MONITOR_PID:-}" ]]; then
        kill "$MONITOR_PID" 2>/dev/null || true
        log_verbose "Monitoring stopped"
    fi
}

# Build state management
save_build_state() {
    local status="$1"
    local message="${2:-}"

    cat > "$STATE_FILE" << EOF
BUILD_STATUS=$status
BUILD_HOST=${CURRENT_HOST:-unknown}
BUILD_START_TIME=${BUILD_START_TIME:-unknown}
BUILD_LAST_PHASE=${CURRENT_PHASE:-unknown}
BUILD_MESSAGE=$message
BUILD_TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
EOF

    log_verbose "Build state saved: $status"
}

load_build_state() {
    if [[ -f "$STATE_FILE" ]]; then
        source "$STATE_FILE"
        log_info "Loaded previous build state: $BUILD_STATUS from $BUILD_TIMESTAMP"
        return 0
    else
        log_verbose "No previous build state found"
        return 1
    fi
}

# Progress tracking
set_build_phase() {
    CURRENT_PHASE="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    log_info "Entering phase: $CURRENT_PHASE"
    save_build_state "IN_PROGRESS" "Phase: $CURRENT_PHASE"
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

# Main CI pipeline with resiliency and monitoring
run_pipeline() {
    local host="$1"
    local status="PASSED"
    CURRENT_HOST="$host"
    BUILD_START_TIME=$(date '+%Y-%m-%d %H:%M:%S')

    # Initialize logging and monitoring
    log_info "Starting NixOS CI/CD pipeline for host: $host"
    log_info "Log file: $LOG_FILE"
    log_info "State file: $STATE_FILE"

    # Set up signal handling
    setup_signal_traps

    # Check for resume capability
    if [[ "$RESUME_BUILD" == "true" ]] && load_build_state; then
        if [[ "$BUILD_STATUS" == "INTERRUPTED" ]]; then
            log_info "Resuming interrupted build from phase: $BUILD_LAST_PHASE"
            # Resume logic would go here - for now, start fresh but log the attempt
        fi
    fi

    # Start monitoring
    start_monitoring "$host"

    # Initial system state
    log_system_state "PIPELINE_START"

    set_build_phase "SETUP"
    setup_ssh

    set_build_phase "VALIDATION"
    if ! validate_flake; then
        status="VALIDATION_FAILED"
    fi

    if [[ "$status" == "PASSED" ]]; then
        set_build_phase "BUILD"
        if ! build_config "$host"; then
            status="BUILD_FAILED"
        fi
    fi

    if [[ "$status" == "PASSED" ]]; then
        set_build_phase "TEST"
        if ! test_config "$host"; then
            status="TEST_FAILED"
        fi
    fi

    # Deployment phase (only if target specified)
    if [[ "$status" == "PASSED" && -n "$DEPLOY_TARGET" ]]; then
        set_build_phase "DEPLOYMENT"
        if ! deploy_config "$host" "$DEPLOY_TARGET"; then
            status="DEPLOY_FAILED"
            if [[ "$ROLLBACK_ON_FAIL" == "true" ]]; then
                set_build_phase "ROLLBACK"
                rollback_config "$host" "$DEPLOY_TARGET"
            fi
        fi
    fi

    # Stop monitoring
    stop_monitoring

    # Final system state
    log_system_state "PIPELINE_END"

    set_build_phase "REPORTING"
    generate_report "$host" "$status"

    # Save final state
    save_build_state "$status" "Pipeline completed"

    if [[ "$status" == "PASSED" ]]; then
        log_success "Pipeline completed successfully"
    else
        error_exit "Pipeline completed with status: $status"
    fi
}

# Show usage
show_usage() {
    cat << EOF
NixOS CI/CD Pipeline with Resiliency and Monitoring

Usage: $0 <host> [options]

Arguments:
   host    Target NixOS configuration host

Environment Variables:
   DEPLOY_TARGET     Target host for deployment (default: none)
   DEPLOY_KEY        SSH private key for deployment (optional)
   DEPLOY_HOST       SSH host for known_hosts (optional)
   ROLLBACK_ON_FAIL  Rollback on deployment failure (default: false)
   VERBOSE           Enable verbose output (default: false)

Resiliency & Monitoring Options:
   STATE_FILE        Build state file (default: .nixos-build-state)
   LOG_FILE          Log file path (default: auto-generated with timestamp)
   MONITOR_INTERVAL  Monitoring interval in seconds (default: 30)
   RESUME_BUILD      Attempt to resume interrupted build (default: false)

Examples:
   $0 dell-potato                                    # Local testing only
   DEPLOY_TARGET=root@dell-potato $0 dell-potato     # Deploy to dell-potato
   VERBOSE=true $0 kraken                            # Verbose local testing
   RESUME_BUILD=true $0 dell-potato                  # Resume interrupted build
   MONITOR_INTERVAL=60 LOG_FILE=my-build.log $0 dell-potato  # Custom monitoring
EOF
}

# Main execution with enhanced error handling
main() {
    # Handle help option
    if [[ $# -eq 1 && ("$1" == "--help" || "$1" == "-h") ]]; then
        show_usage
        exit 0
    fi

    if [[ $# -lt 1 ]]; then
        show_usage
        exit 1
    fi

    local host="$1"

    # Check if host configuration exists (skip for help)
    if [[ "$host" != "--help" && "$host" != "-h" ]]; then
        if ! nix eval ".#nixosConfigurations.$host" &>/dev/null; then
            error_exit "Host configuration '$host' not found in flake"
        fi
    fi

    # Validate environment and dependencies
    log_info "Validating environment..."
    if ! command -v nix &> /dev/null; then
        error_exit "nix command not found in PATH"
    fi

    if ! command -v uptime &> /dev/null; then
        log_warning "uptime command not available - system monitoring will be limited"
    fi

    if ! command -v sensors &> /dev/null; then
        log_verbose "sensors command not available - temperature monitoring disabled"
    fi

    log_info "Environment validation complete"

    # Run the pipeline with error handling
    if run_pipeline "$host"; then
        log_success "Build completed successfully"
        exit 0
    else
        local exit_code=$?
        log_error "Build failed with exit code $exit_code"
        exit $exit_code
    fi
}

main "$@"