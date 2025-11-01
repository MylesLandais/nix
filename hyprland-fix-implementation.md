# Hyprland Display/Keyboard Fix Implementation Guide

## Quick Start

### Step 1: Test Primary Fix (NVIDIA KMS)

The most likely cause is the `nvidia_drm.modeset=1` parameter causing display resets. I've already commented it out in your configuration.

```bash
# Rebuild and test
sudo nixos-rebuild switch
# Reboot completely
sudo reboot
```

**After reboot, test:**
1. Login through your display manager
2. Check if display restarts during password entry
3. Verify keyboard and mouse work immediately in Hyprland

**If this fixes the issue:** ✅ You're done! The problem was NVIDIA KMS causing display resets.

**If the issue persists:** Continue to Step 2.

### Step 2: Run Diagnostic Script

If the primary fix doesn't work, gather diagnostic information:

```bash
# Switch to TTY (Ctrl+Alt+F2) before logging in
./scripts/hyprland-debug.sh
# Follow the prompts, then login via display manager
# Press Ctrl+C when the issue occurs
```

This will create debug files in `/tmp/hyprland-debug-*` with detailed analysis.

### Step 3: Apply Secondary Fixes

If the primary fix doesn't work, apply these additional fixes one at a time:

#### Fix 3A: Add Explicit Display Manager

Add to [`hosts/cerberus/configuration.nix`](hosts/cerberus/configuration.nix):

```nix
services.xserver.displayManager.sddm = {
  enable = true;
  wayland.enable = true;
};
```

```bash
sudo nixos-rebuild switch
sudo reboot
```

#### Fix 3B: Disable USB Autosuspend

If still broken, add to [`hosts/cerberus/configuration.nix`](hosts/cerberus/configuration.nix):

```nix
boot.kernelParams = [ "usbcore.autosuspend=-1" ];
```

```bash
sudo nixos-rebuild switch
sudo reboot
```

#### Fix 3C: Alternative NVIDIA Settings

If the issue persists, modify your NVIDIA configuration:

```nix
hardware.nvidia = {
  modesetting.enable = true;
  powerManagement.enable = true;  # Enable instead of disable
  powerManagement.finegrained = false;
  open = false;  # Use proprietary driver
  nvidiaSettings = true;
  package = config.boot.kernelPackages.nvidiaPackages.stable;  # Use stable
};
```

### Step 4: Verification

After each fix, verify:

1. **No display restart** during login
2. **Keyboard works immediately** in Hyprland
3. **Mouse cursor moves and clicks** work
4. **Can open terminal** and type commands
5. **Test multiple reboots** to ensure consistency

### Step 5: If All Else Fails

If none of the fixes work:

1. **Share the diagnostic output** from Step 2
2. **Try TTY login** to isolate the issue:
   ```bash
   # Switch to TTY (Ctrl+Alt+F2)
   # Login with your username/password
   Hyprland
   ```
3. **Check if it works from TTY** - this helps identify if it's a display manager issue

## Expected Results

### Working System Should Show:
- Smooth login without display flicker
- Immediate keyboard/mouse response
- No USB device resets in logs
- Clean journal logs without DRM errors

### Common Error Patterns to Look For:
- `nvidia-drm: failed to set mode` → NVIDIA driver issue
- `USB disconnect, device number X` → USB power management issue
- `session failed to start` → Display manager handoff issue

## Rollback Plan

If any fix makes things worse:

```bash
# Rollback to previous generation
sudo nixos-rebuild switch --rollback
# Or list generations and pick a working one
sudo nixos-rebuild list-generations
sudo nixos-rebuild switch --profile-name /nix/var/nix/profiles/system-<working>-link
```

## Success Criteria

✅ **Primary Fix Success:** Login works without display restart or keyboard issues  
✅ **Secondary Fix Success:** One of the additional fixes resolves the issue  
✅ **Diagnostic Success:** Even if not fixed, we have clear logs showing the root cause  

## Next Steps

1. **Test the primary fix first** (already applied)
2. **If needed, run the diagnostic script** 
3. **Apply secondary fixes one at a time**
4. **Share results** so we can refine the solution

The diagnostic script and configuration fixes are now ready for testing.