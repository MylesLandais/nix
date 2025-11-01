# Hyprland SDDM Fix Implementation Guide

## Updated Configuration

I've updated your [`hosts/cerberus/configuration.nix`](hosts/cerberus/configuration.nix) with your friend's working SDDM configuration:

### Changes Made:
1. **Added SDDM with Wayland support** using your friend's exact configuration
2. **Added sddm-astronaut theme** with japanese_aesthetic embedded theme
3. **Added kdePackages.qtmultimedia** for better multimedia support
4. **Kept NVIDIA KMS disabled** (primary fix for display restart)

### Key Configuration Added:
```nix
services.xserver.displayManager.sddm = {
  enable = true;
  wayland.enable = true;
  theme = lib.mkForce "sddm-astronaut-theme";
  extraPackages = with pkgs; [
    sddm-astronaut
  ];
  settings = {
    Theme = {
      Current = "sddm-astronaut-theme";
    };
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

✅ **SDDM login screen appears** with astronaut theme  
✅ **No display restart** during password entry  
✅ **Smooth transition** to Hyprland  
✅ **Keyboard works immediately** in Hyprland  
✅ **Mouse cursor moves and clicks** work  
✅ **Can open terminal** and type commands  

### Step 4: Test Multiple Times
Reboot 2-3 times to ensure consistency:
```bash
sudo reboot
# Test login again
sudo reboot
# Test login again
```

## If Issues Persist

### Run Diagnostic Script
```bash
# Switch to TTY (Ctrl+Alt+F2) before logging in
./scripts/hyprland-debug.sh
# Follow prompts, login via SDDM, press Ctrl+C when issue occurs
```

### Additional Fixes Available
If still experiencing issues, try these in order:

#### Fix A: Disable USB Autosuspend
Add to [`hosts/cerberus/configuration.nix`](hosts/cerberus/configuration.nix):
```nix
boot.kernelParams = [ "usbcore.autosuspend=-1" ];
```

#### Fix B: Alternative NVIDIA Settings
Modify your NVIDIA configuration:
```nix
hardware.nvidia = {
  modesetting.enable = true;
  powerManagement.enable = true;  # Enable instead of disable
  powerManagement.finegrained = false;
  open = false;  # Use proprietary driver
  nvidiaSettings = true;
  package = config.boot.kernelPackages.nvidiaPackages.stable;
};
```

## Expected Results

### Working System Should Show:
- Beautiful SDDM astronaut theme at login
- Smooth login without display flicker
- Immediate keyboard/mouse response in Hyprland
- No USB device resets in logs
- Clean journal logs without DRM errors

### Success Indicators:
```bash
# Check SDDM is running
systemctl status sddm.service

# Check Wayland session
echo $XDG_SESSION_TYPE  # Should output "wayland"

# Check NVIDIA driver
nvidia-smi  # Should show GPU info without errors
```

## Rollback Plan

If any issues occur:

```bash
# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# Or list generations and pick a working one
sudo nixos-rebuild list-generations
```

## Why This Configuration Works

1. **SDDM with Wayland**: Better Wayland session handoff than default display manager
2. **Astronaut Theme**: Proven to work with Hyprland/NVIDIA setups
3. **NVIDIA KMS Disabled**: Prevents display driver resets during login
4. **Qt Multimedia**: Ensures proper multimedia support in Wayland

## Next Steps

1. **Rebuild and test** the updated configuration
2. **Verify all success criteria** are met
3. **Test multiple reboots** for consistency
4. **Share results** so we can confirm the fix is working

The combination of your friend's working SDDM configuration with the NVIDIA KMS fix should resolve the display restart and keyboard/mouse unresponsiveness issues.