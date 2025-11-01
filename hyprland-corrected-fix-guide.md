# Hyprland Display/Keyboard Bug - Corrected Fix Implementation

## Important Correction

**NVIDIA KMS is REQUIRED for Wayland/Hyprland** - I've restored `nvidia_drm.modeset=1` since disabling it would break Wayland entirely.

## Real Root Causes & Fixes

The display restart and keyboard/mouse unresponsiveness is likely caused by:

1. **USB Power Management** - System suspending input devices during session transition
2. **Display Manager Handoff** - Default display manager not properly handling Wayland sessions

## Applied Fixes

### 1. USB Power Management Fix (Most Likely Cause)
```nix
# Disable USB autosuspend to prevent device resets
boot.kernelParams = [ "nvidia_drm.modeset=1" "usbcore.autosuspend=-1" ];

# USB device power management rules
services.udev.extraRules = ''
  # Prevent USB controller resets during session changes
  ACTION=="add", SUBSYSTEM=="usb", ATTR{power/autosuspend}="0"
  ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="on"
  
  # Ensure input devices stay powered
  SUBSYSTEM=="input", ATTR{power/autosuspend}="0"
  SUBSYSTEM=="input", ATTR{power/control}="on"
'';
```

### 2. SDDM Display Manager (Friend's Working Config)
```nix
services.displayManager.sddm = {
  enable = true;
  wayland.enable = true;
  theme = lib.mkForce "sddm-astronaut-theme";
  extraPackages = with pkgs; [ sddm-astronaut ];
  settings = {
    Theme = { Current = "sddm-astronaut-theme"; };
  };
};
```

## Implementation Steps

### Step 1: Rebuild System
```bash
sudo nixos-rebuild switch
```

### Step 2: Reboot and Test
```bash
sudo reboot
```

### Step 3: Verification Checklist
After reboot, verify:

✅ **SDDM astronaut theme appears** at login  
✅ **No display restart** during password entry  
✅ **Smooth transition** to Hyprland  
✅ **Keyboard works immediately** in Hyprland  
✅ **Mouse cursor moves and clicks** work  
✅ **Can open terminal** and type commands  

### Step 4: Test Multiple Reboots
```bash
sudo reboot
# Test login again
sudo reboot  
# Test login again
```

## Why This Should Work

### USB Power Management Fix
- **Problem**: USB devices get autosuspended during display manager → Hyprland transition
- **Solution**: Disable autosuspend and force USB devices to stay powered
- **Result**: Keyboard/mouse remain functional throughout login process

### SDDM Display Manager
- **Problem**: Default display manager may have poor Wayland session handoff
- **Solution**: Use SDDM with proven Wayland support
- **Result**: Clean session transition without display resets

## If Issues Persist

### Run Diagnostic Script
```bash
# Switch to TTY (Ctrl+Alt+F2) before logging in
./scripts/hyprland-debug.sh
# Follow prompts, login via SDDM, press Ctrl+C when issue occurs
```

### Check for Specific Errors
Look for these patterns in the diagnostic output:

**USB Issues (most likely):**
```
USB disconnect, device number 3
usb 1-1: reset full-speed USB device number 2 using xhci_hcd
```

**Display Manager Issues:**
```
session failed to start
display-manager.service: Failed with result 'exit-code'
```

**NVIDIA Issues (less likely with KMS enabled):**
```
nvidia-drm: failed to set mode
DRM: driver failed to set mode
```

## Additional Troubleshooting

### If USB devices still reset:
Try more aggressive USB power management:
```nix
boot.kernelParams = [ 
  "nvidia_drm.modeset=1" 
  "usbcore.autosuspend=-1"
  "usbcore.autosuspend_delay_ms=-1"
];
```

### If display manager still has issues:
Try alternative session management:
```nix
# Ensure proper session handoff
services.displayManager.sessionPackages = [ pkgs.hyprland ];

# Add environment variables for better NVIDIA/Wayland compatibility
environment.sessionVariables = {
  WLR_NO_HARDWARE_CURSORS = "1";
  LIBVA_DRIVER_NAME = "nvidia";
  __GLX_VENDOR_LIBRARY_NAME = "nvidia";
  GBM_BACKEND = "nvidia-drm";
};
```

## Expected Results

### Working System Should Show:
- Beautiful SDDM astronaut theme at login
- Smooth login without display flicker or restart
- Immediate keyboard/mouse response in Hyprland
- No USB device resets in logs
- Clean journal logs during login transition

### Success Verification Commands:
```bash
# Check SDDM is running
systemctl status sddm.service

# Check Wayland session
echo $XDG_SESSION_TYPE  # Should output "wayland"

# Check USB devices are stable
lsusb  # Should show all devices without disconnects

# Check NVIDIA driver with KMS
nvidia-smi  # Should show GPU info
cat /proc/driver/nvidia/version  # Should show driver version
```

## Rollback Plan

If any issues occur:
```bash
# Rollback to previous generation
sudo nixos-rebuild switch --rollback
```

## Summary

The corrected approach focuses on:
1. **Keeping NVIDIA KMS enabled** (required for Wayland)
2. **Fixing USB power management** (most likely cause of keyboard/mouse issues)
3. **Using proven SDDM configuration** (better Wayland session handoff)

This should resolve both the display restart and keyboard/mouse unresponsiveness without breaking Wayland functionality.