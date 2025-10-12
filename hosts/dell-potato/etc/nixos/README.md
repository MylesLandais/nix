# Dell OptiPlex NixOS Configuration

This directory contains the NixOS configuration for the Dell OptiPlex workstation, optimized for both Intel integrated graphics and AMD discrete GPU support.

## Hardware Configuration

- **System**: Dell OptiPlex
- **CPU**: Intel Core i5-6500 (Skylake)
- **Graphics**: Intel HD Graphics 530 (primary), AMD discrete GPU support (when present)
- **Kernel**: CachyOS kernel (performance-optimized)
- **Desktop**: GNOME with GDM
- **Audio**: PipeWire with low-latency configuration
- **Networking**: NetworkManager
- **User**: warby

## Key Features

### CachyOS Kernel Integration
- Performance-optimized kernel from Chaotic Nyx
- Enhanced responsiveness and gaming performance
- Latest kernel features and patches

### AMD Graphics Support
- Full AMD GPU driver stack (amdgpu)
- ROCm OpenCL support for compute workloads
- Vulkan RADV driver for gaming
- Hardware-accelerated video decoding (VA-API)
- Kernel parameters optimized for AMD GPUs

### Home Manager Integration
- Declarative user environment management
- Comprehensive development toolset
- Custom shell configurations (Bash, Fish)
- Starship prompt with custom theme

## Modules

- `configuration.nix`: Main system configuration with CachyOS kernel and AMD graphics support
- `hardware-configuration.nix`: Hardware-specific settings (generated)
- `modules/graphics.nix`: AMD discrete GPU configuration module
- `modules/media.nix`: Media and entertainment packages
- `modules/syncthing-tailscale.nix`: File synchronization and VPN
- `home-manager/home.nix`: User environment configuration

## AMD Graphics Setup

The configuration includes support for AMD Radeon RX series GPUs. Key settings:

- **Kernel Parameters**:
  - `amdgpu.si_support=1`: Enable Southern Islands (GCN 1.0) support
  - `amdgpu.cik_support=1`: Enable Sea Islands/Cape Verde (GCN 1.1) support
  - `radeon.si_support=0`: Disable legacy radeon driver for SI GPUs
  - `radeon.cik_support=0`: Disable legacy radeon driver for CIK GPUs

- **Environment Variables**:
  - `AMD_VULKAN_ICD=RADV`: Force AMD Vulkan driver
  - `ROCR_VISIBLE_DEVICES=all`: Enable all ROCm devices

- **Driver Stack**:
  - Mesa graphics drivers
  - ROCm for OpenCL compute
  - VA-API for video acceleration
  - Vulkan loader and validation layers

## Usage

### Applying Configuration
```bash
sudo nixos-rebuild switch --flake /etc/nixos#dell-potato
```

### Updating Flake Inputs
```bash
sudo nix flake update /etc/nixos
sudo nixos-rebuild switch --flake /etc/nixos#dell-potato
```

### Home Manager Updates
```bash
home-manager switch --flake /etc/nixos#dell-potato
```

## Hardware Detection and AMD GPU

The current system was scanned and found to have:
- Intel HD Graphics 530 (device ID: 0x1912)
- No AMD discrete GPU currently detected

If an AMD GPU is added to the system:
1. The `modules/graphics.nix` will automatically configure AMD drivers
2. Kernel parameters will enable AMD GPU support
3. ROCm and Vulkan drivers will be available
4. Graphics tools (`amdgpu_top`, `glxinfo`, etc.) will be installed

## Testing AMD Graphics

After adding an AMD GPU, verify functionality:

```bash
# Check GPU detection
lspci | grep -i amd

# Test OpenGL
glxinfo | grep "OpenGL renderer"

# Test Vulkan
vulkaninfo --summary

# Monitor GPU
amdgpu_top

# Test VA-API
vainfo
```

## BIOS Settings

- Secure Boot: Disabled
- UEFI boot mode: Enabled
- Wake-on-LAN: Enabled for remote management

## Troubleshooting

### Kernel Issues
If CachyOS kernel causes problems, temporarily switch to standard kernel:
```nix
boot.kernelPackages = pkgs.linuxPackages_latest;
```

### Graphics Issues
- For dual graphics setups, use `DRI_PRIME=1` to force discrete GPU
- Check kernel parameters if display issues occur
- Verify Vulkan ICD configuration

### Performance Tuning
- CachyOS kernel provides automatic performance optimizations
- Use `gamemode` for gaming performance
- Monitor with `amdgpu_top` for GPU utilization

## Maintenance

- Regularly update flake inputs for latest packages
- Monitor kernel and graphics driver updates
- Test builds before deploying to production
- Keep hardware-configuration.nix synchronized with actual hardware

---

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
