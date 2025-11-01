#!/usr/bin/env bash
# Hyprland Display/Keyboard Debug Script
# Run this before logging in to capture the login process

set -e

echo "=== Hyprland Debug Script ==="
echo "This script will help diagnose the display/keyboard issue"
echo ""

# Create debug directory
DEBUG_DIR="/tmp/hyprland-debug-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$DEBUG_DIR"

echo "Debug files will be saved to: $DEBUG_DIR"
echo ""

# Function to capture system state
capture_state() {
    local name="$1"
    echo "Capturing $name..."
    
    # System info
    uname -a > "$DEBUG_DIR/${name}-system.txt"
    nixos-version >> "$DEBUG_DIR/${name}-system.txt"
    
    # Display manager status
    systemctl status display-manager.service > "$DEBUG_DIR/${name}-display-manager.txt" 2>&1 || true
    
    # USB devices
    lsusb > "$DEBUG_DIR/${name}-usb.txt"
    
    # NVIDIA status
    nvidia-smi > "$DEBUG_DIR/${name}-nvidia.txt" 2>&1 || true
    cat /proc/driver/nvidia/version > "$DEBUG_DIR/${name}-nvidia-version.txt" 2>&1 || true
    
    # Kernel messages (last 50 lines)
    dmesg -T | tail -50 > "$DEBUG_DIR/${name}-dmesg.txt"
    
    # Environment variables
    env | grep -E "(XDG|WAYLAND|DISPLAY)" > "$DEBUG_DIR/${name}-env.txt" 2>&1 || true
    
    echo "State captured: $name"
}

# Capture initial state (before login)
capture_state "before-login"

echo ""
echo "Now logging the journal during login..."
echo "Press Ctrl+C after you experience the issue (display restart/keyboard not working)"
echo ""

# Start journal logging
journalctl -f > "$DEBUG_DIR/journal.log" &
JOURNAL_PID=$!

# Wait for user to stop logging
echo "Journal logging started (PID: $JOURNAL_PID)"
echo "Login via your display manager now..."
echo "Press Ctrl+C when the issue occurs"

# Wait for Ctrl+C
trap "kill $JOURNAL_PID 2>/dev/null || true" INT
wait $JOURNAL_PID 2>/dev/null || true

# Capture state after issue
capture_state "after-login"

# Analyze logs
echo ""
echo "Analyzing logs for common issues..."

# Check for NVIDIA/DRM errors
echo "=== NVIDIA/DRM Errors ===" > "$DEBUG_DIR/analysis.txt"
grep -i "nvidia\|drm\|gpu" "$DEBUG_DIR/journal.log" | tail -20 >> "$DEBUG_DIR/analysis.txt" || echo "No NVIDIA/DRM errors found" >> "$DEBUG_DIR/analysis.txt"

# Check for USB resets
echo "" >> "$DEBUG_DIR/analysis.txt"
echo "=== USB Resets ===" >> "$DEBUG_DIR/analysis.txt"
grep -i "usb.*reset\|usb.*disconnect" "$DEBUG_DIR/journal.log" | tail -10 >> "$DEBUG_DIR/analysis.txt" || echo "No USB resets found" >> "$DEBUG_DIR/analysis.txt"

# Check for display manager errors
echo "" >> "$DEBUG_DIR/analysis.txt"
echo "=== Display Manager Errors ===" >> "$DEBUG_DIR/analysis.txt"
grep -i "display.*manager\|gdm\|sddm\|session.*failed" "$DEBUG_DIR/journal.log" | tail -10 >> "$DEBUG_DIR/analysis.txt" || echo "No display manager errors found" >> "$DEBUG_DIR/analysis.txt"

# Check for Hyprland errors
echo "" >> "$DEBUG_DIR/analysis.txt"
echo "=== Hyprland Errors ===" >> "$DEBUG_DIR/analysis.txt"
grep -i "hyprland\|compositor\|wayland" "$DEBUG_DIR/journal.log" | tail -20 >> "$DEBUG_DIR/analysis.txt" || echo "No Hyprland errors found" >> "$DEBUG_DIR/analysis.txt"

# Display analysis
echo ""
cat "$DEBUG_DIR/analysis.txt"

echo ""
echo "=== Summary ==="
echo "Debug files saved to: $DEBUG_DIR"
echo "Key files to check:"
echo "  - $DEBUG_DIR/analysis.txt (automated analysis)"
echo "  - $DEBUG_DIR/journal.log (full journal during login)"
echo "  - $DEBUG_DIR/before-login-*.txt (system state before login)"
echo "  - $DEBUG_DIR/after-login-*.txt (system state after issue)"
echo ""
echo "Share these files when seeking help with the issue."