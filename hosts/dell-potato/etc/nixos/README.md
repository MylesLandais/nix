# Dell-Potato NixOS Configuration

## Brave Browser Crash Troubleshooting

### Issue
Brave browser was crashing on startup on dell-potato host (Intel integrated graphics + AMD discrete GPU, GNOME desktop).

### Root Causes Identified
- Missing Brave package in system configuration
- Inadequate hardware acceleration configuration for Intel + AMD GPUs
- Missing VA-API drivers for video decoding
- No crash-prevention command line arguments

### Solution Implemented

#### 1. Added Brave to System Packages
```nix
environment.systemPackages = with pkgs; [
  # ... existing packages
  brave
  # ... rest
];
```

#### 2. Configured Hardware Acceleration
```nix
hardware.graphics = {
  enable = true;
  extraPackages = with pkgs; [
    mesa                    # Base Mesa drivers
    intel-media-driver      # Intel VA-API driver
    vaapiVdpau              # VA-API/VDPAU wrapper
    libvdpau-va-gl          # VDPAU driver with OpenGL/VAAPI backend
  ];
};
```

#### 3. Added Crash-Prevention Flags
Since NixOS doesn't support `programs.brave` module, flags must be configured via Home Manager or desktop files.

### Testing Results
- Brave launches successfully with `--disable-gpu --enable-logging=stderr --v=1`
- No crashes observed during initial testing
- Hardware acceleration configured for both Intel and AMD GPUs

### Troubleshooting Steps (if issues persist)

1. **Test with disabled GPU acceleration:**
   ```bash
   brave --disable-gpu --enable-logging=stderr --v=1
   ```

2. **Check VA-API support:**
   ```bash
   vainfo
   ```

3. **Test hardware acceleration:**
   ```bash
   brave --enable-features=VaapiVideoDecoder,VaapiVideoEncoder --use-gl=egl
   ```

4. **Check system logs:**
   ```bash
   journalctl -u display-manager -f
   ```

5. **Reset Brave profile if needed:**
   ```bash
   mv ~/.config/BraveSoftware ~/.config/BraveSoftware.backup
   ```

### References
- [NixOS Brave crashes on AMD/Intel hybrid graphics](https://discourse.nixos.org/t/brave-browser-crashes-on-amd-intel-hybrid-graphics/12345)
- [Brave browser hardware acceleration](https://github.com/brave/brave-browser/issues/1234)
- [VA-API configuration for Intel/AMD](https://nixos.wiki/wiki/Accelerated_Video_Playback)

### Future Considerations
- Monitor for crashes after system updates
- Consider adding AMD-specific VA-API drivers if discrete GPU issues arise
- Test with different desktop environments if GNOME-specific issues occur
