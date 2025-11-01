# NixOS Hyprland Display/Keyboard Bug - Diagnostic & Resolution Plan

## Problem Analysis

Based on your cerberus configuration, I've identified several potential causes for the display restart and keyboard/mouse unresponsiveness:

### Current Configuration Summary:
- **GPU**: NVIDIA with proprietary drivers (`hardware.nvidia.open = true`)
- **Display Manager**: Default NixOS display manager (not explicitly configured)
- **Kernel Parameters**: `nvidia_drm.modeset=1`
- **Window Manager**: Hyprland with Wayland
- **Kernel**: `linuxPackages_cachyos` (performance-focused kernel)

### Most Likely Causes:
1. **NVIDIA KMS conflict** - The `nvidia_drm.modeset=1` parameter may be causing display resets
2. **USB power management** - System suspending input devices during session transition
3. **Default display manager issues** - The implicit display manager may have Wayland handoff problems

## Diagnostic Commands

### Step 1: Identify Display Manager
```bash
# Check what display manager is actually running
systemctl status display-manager.service
# Or
ps aux | grep -E "(gdm|sddm|lightdm|ly|xdm)"

# Check current session
echo $XDG_SESSION_TYPE
echo $XDG_CURRENT_DESKTOP
```

### Step 2: Capture Login Process Logs
```bash
# Before logging in, start logging in a TTY or SSH session
sudo journalctl -f > /tmp/login-debug.log

# Then login via the display manager, wait for the issue, then Ctrl+C
# Analyze the logs
grep -B 5 -A 10 "hyprland\|display\|drm\|reset\|usb" /tmp/login-debug.log
```

### Step 3: Check GPU/Driver Status
```bash
# NVIDIA driver status
nvidia-smi
cat /proc/driver/nvidia/version

# Check for DRM errors
sudo dmesg -T | grep -i "drm\|nvidia" | tail -20

# Check for USB resets
sudo dmesg -T | grep -i "usb.*reset" | tail -10
```

### Step 4: Check System Generations
```bash
# List recent system generations
nixos-rebuild list-generations | head -10

# Compare with a working generation (if known)
nix-diff /nix/var/nix/profiles/system-<old>-link /nix/var/nix/profiles/system-<new>-link
```

## Targeted Fixes

### Fix 1: NVIDIA Driver Configuration
Add to [`hosts/cerberus/configuration.nix`](hosts/cerberus/configuration.nix):

```nix
# Try disabling KMS temporarily
# boot.kernelParams = [ "nvidia_drm.modeset=1" ];  # Comment this out

# Or try alternative NVIDIA settings
hardware.nvidia = {
  modesetting.enable = true;
  powerManagement.enable = true;  # Try enabling power management
  powerManagement.finegrained = false;
  open = false;  # Try proprietary driver instead of open
  nvidiaSettings = true;
  package = config.boot.kernelPackages.nvidiaPackages.stable;  # Try stable instead of latest
};
```

### Fix 2: USB Power Management
Add to [`hosts/cerberus/configuration.nix`](hosts/cerberus/configuration.nix):

```nix
# Disable USB autosuspend
boot.kernelParams = [ "usbcore.autosuspend=-1" ];

# Or add USB controller reset prevention
services.udev.extraRules = ''
  # Prevent USB controller resets during session changes
  ACTION=="add", SUBSYSTEM=="usb", ATTR{power/autosuspend}="0"
  ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="on"
'';
```

### Fix 3: Explicit Display Manager
Add to [`hosts/cerberus/configuration.nix`](hosts/cerberus/configuration.nix):

```nix
# Use SDDM (better Wayland support than default)
services.xserver.displayManager.sddm = {
  enable = true;
  wayland.enable = true;
};

# Or use Ly (minimal TTY-based display manager)
# programs.ly.enable = true;
```

### Fix 4: Hyprland Session Management
Update [`hyprland.nix`](hyprland.nix) exec-once section:

```nix
"exec-once" = [
  "dbus-update-activation-environment --systemd DISPLAY HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
  "sleep 1 && systemctl --user restart hyprland-session.target"
  "hyprpanel &"
  "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
  "hyprpaper &"
  "sleep 2 && add_record_player"  # Delay USB audio setup
];
```

## Testing Procedure

### Test 1: Isolate Display Manager
```bash
# Temporarily disable display manager to test TTY login
sudo systemctl stop display-manager.service
# Switch to TTY (Ctrl+Alt+F2), login, run: Hyprland
# Test if keyboard/mouse work
```

## Diagnostic Script

Create this script at `scripts/hyprland-debug.sh`:

```bash
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
```

Make it executable:
```bash
chmod +x scripts/hyprland-debug.sh
```

## Quick Fix Attempts

### Fix 1: Remove NVIDIA KMS Parameter (Most Likely)

Edit [`hosts/cerberus/configuration.nix`](hosts/cerberus/configuration.nix):
```nix
# Comment out this line:
# boot.kernelParams = [ "nvidia_drm.modeset=1" ];
```

Then rebuild and test:
```bash
sudo nixos-rebuild switch
# Reboot and test login
```

### Fix 2: Add Explicit Display Manager

If Fix 1 doesn't work, add to [`hosts/cerberus/configuration.nix`](hosts/cerberus/configuration.nix):
```nix
services.xserver.displayManager.sddm = {
  enable = true;
  wayland.enable = true;
};
```

### Fix 3: Disable USB Autosuspend

If the issue persists, add to [`hosts/cerberus/configuration.nix`](hosts/cerberus/configuration.nix):
```nix
boot.kernelParams = [ "usbcore.autosuspend=-1" ];
```

## Next Steps

1. **Run the diagnostic script** before your next login attempt
2. **Try Fix 1 first** (remove NVIDIA KMS parameter)
3. **If still broken, try Fix 2** (add SDDM display manager)
4. **If still broken, try Fix 3** (disable USB autosuspend)
5. **Share the diagnostic output** if none of the fixes work

The diagnostic script will help identify exactly what's failing during the login process.

### Test 2: USB Device Check
```bash
# Check USB devices before and after login
lsusb > /tmp/usb-before.txt
# Login via display manager
lsusb > /tmp/usb-after.txt
diff /tmp/usb-before.txt /tmp/usb-after.txt
```

### Test 3: Kernel Parameter Testing
1. Remove `nvidia_drm.modeset=1` and rebuild
2. Test login
3. If still broken, add `usbcore.autosuspend=-1`
4. Test again
5. Continue with one change at a time

## Resolution Verification

After applying any fix:

1. **Complete reboot** (not just logout)
2. **Test login sequence**:
   - ✅ No display flicker/restart during password entry
   - ✅ Keyboard immediately responsive in Hyprland
   - ✅ Mouse cursor moves and clicks work
   - ✅ Can open terminal and type commands
3. **Repeat test 2-3 times** to ensure consistency
4. **Check logs** to confirm no errors:
   ```bash
   journalctl -b -0 -u display-manager.service
   journalctl -b -0 --user -u hyprland-session.target
   ```

## Priority Order for Testing

1. **First**: Remove `nvidia_drm.modeset=1` (most likely cause)
2. **Second**: Add explicit display manager (SDDM with Wayland)
3. **Third**: Disable USB autosuspend
4. **Fourth**: Adjust NVIDIA power management settings

## Expected Log Patterns

### Working System:
```
display-manager.service: Started Display Manager.
gdm-password]: pam_unix(gdm-password:auth): authentication succeeded
hyprland-session.target: Starting Hyprland Wayland Session...
hyprland-session.target: Reached target Hyprland Wayland Session.
```

### Broken System (look for these):
```
nvidia-drm: failed to set mode
USB disconnect, device number 3
kernel BUG at drivers/gpu/drm/nvidia/nvidia-drm.c
systemd-logind: Failed to start session scope