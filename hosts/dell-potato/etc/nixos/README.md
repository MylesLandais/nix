# NixOS Configuration

This repository contains the NixOS system configuration for a media server setup with DVD/Blu-ray ripping capabilities.

## Structure

- `configuration.nix` - Main system configuration
- `modules/media.nix` - Media-specific configuration module
- `hardware-configuration.nix` - Hardware-specific settings

## Features

### Media Processing
- **MakeMKV** - DVD/Blu-ray ripping
- **HandBrake CLI** - Video transcoding
- **mpv** - Media playback (preferred over VLC)
- **dvdbackup** - DVD backup utilities
- **mediainfo** - Media file analysis
- **ffmpeg** - Video/audio processing
- **mkvtoolnix** - MKV container tools

### Directory Structure
- `/media/movies/` - Movie files
- `/media/tv/` - TV show files  
- `/media/ripping/` - Temporary ripping workspace

### Hardware Support
- Optical drive support with proper permissions
- User groups: cdrom, audio, video for media access

## Usage

1. Test configuration: `sudo nixos-rebuild test`
2. Apply configuration: `sudo nixos-rebuild switch`
3. Check media tools: `which makemkv HandBrakeCLI mpv`

## Configuration Modules

### Main Configuration (`configuration.nix`)
- Boot configuration and kernel modules
- System-wide packages and services
- User configuration and permissions
- Network and hardware settings

### Media Module (`modules/media.nix`)
- Media processing packages (MakeMKV, HandBrake, etc.)
- Media player software (mpv preferred, VLC fallback)
- Hardware access configuration for optical drives
- Directory structure for organized media storage
- User group memberships for media hardware access

## Hardware Requirements

- Optical drive (DVD/Blu-ray) with proper /dev/sr* access
- Sufficient storage for ripping operations in /media/
- Network connectivity for package management

## Maintenance

This configuration follows NixOS best practices:
- Modular configuration structure
- Version control with detailed commit messages
- Declarative package management
- Proper user permissions and hardware access
- Regular testing before applying changes

## Deployment

To apply this configuration on a new NixOS system:

1. Clone this repository to `/etc/nixos/`
2. Review and adjust `hardware-configuration.nix` for your hardware
3. Test with `sudo nixos-rebuild test`
4. Apply with `sudo nixos-rebuild switch`

Generated and managed following the WARP.md documentation standards.

## Version History

- **Latest**: Modular media configuration with dedicated media.nix module
- **Initial**: Basic system configuration backup

See git log for detailed change history.


## System Information

```
=========================================
      System Information Report
  Generated on: Thu Oct  9 07:29:03 PM EDT 2025
=========================================

### Operating System Details ###
--------------------------------------------------
Running: cat /etc/os-release
ANSI_COLOR="0;38;2;126;186;228"
BUG_REPORT_URL="https://github.com/NixOS/nixpkgs/issues"
BUILD_ID="25.11.20251002.7df7ff7"
CPE_NAME="cpe:/o:nixos:nixos:25.11"
DEFAULT_HOSTNAME=nixos
DOCUMENTATION_URL="https://nixos.org/learn.html"
HOME_URL="https://nixos.org/"
ID=nixos
ID_LIKE=""
IMAGE_ID=""
IMAGE_VERSION=""
LOGO="nix-snowflake"
NAME=NixOS
PRETTY_NAME="NixOS 25.11 (Xantusia)"
SUPPORT_URL="https://nixos.org/community.html"
VARIANT=""
VARIANT_ID=""
VENDOR_NAME=NixOS
VENDOR_URL="https://nixos.org/"
VERSION="25.11 (Xantusia)"
VERSION_CODENAME=xantusia
VERSION_ID="25.11"
--------------------------------------------------


### Kernel Version ###
--------------------------------------------------
Running: uname -a
Linux potato 6.16.9-zen1 #1-NixOS ZEN SMP PREEMPT_DYNAMIC Tue Jan  1 00:00:00 UTC 1980 x86_64 GNU/Linux
--------------------------------------------------


### CPU Information ###
--------------------------------------------------
Running: lscpu
Architecture:                            x86_64
CPU op-mode(s):                          32-bit, 64-bit
Address sizes:                           39 bits physical, 48 bits virtual
Byte Order:                              Little Endian
CPU(s):                                  4
On-line CPU(s) list:                     0-3
Vendor ID:                               GenuineIntel
Model name:                              Intel(R) Core(TM) i5-6500 CPU @ 3.20GHz
CPU family:                              6
Model:                                   94
Thread(s) per core:                      1
Core(s) per socket:                      4
Socket(s):                               1
Stepping:                                3
CPU(s) scaling MHz:                      33%
CPU max MHz:                             3600.0000
CPU min MHz:                             800.0000
BogoMIPS:                                6399.96
Flags:                                   fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush dts acpi mmx fxsr sse sse2 ss ht tm pbe syscall nx pdpe1gb rdtscp lm constant_tsc art arch_perfmon pebs bts rep_good nopl xtopology nonstop_tsc cpuid aperfmperf pni pclmulqdq dtes64 monitor ds_cpl vmx smx est tm2 ssse3 sdbg fma cx16 xtpr pdcm pcid sse4_1 sse4_2 x2apic movbe popcnt tsc_deadline_timer aes xsave avx f16c rdrand lahf_lm abm 3dnowprefetch cpuid_fault epb pti ssbd ibrs ibpb stibp tpr_shadow flexpriority ept vpid ept_ad fsgsbase tsc_adjust bmi1 avx2 smep bmi2 erms invpcid mpx rdseed adx smap clflushopt intel_pt xsaveopt xsavec xgetbv1 xsaves dtherm ida arat pln pts hwp hwp_notify hwp_act_window hwp_epp vnmi md_clear flush_l1d arch_capabilities
Virtualization:                          VT-x
L1d cache:                               128 KiB (4 instances)
L1i cache:                               128 KiB (4 instances)
L2 cache:                                1 MiB (4 instances)
L3 cache:                                6 MiB (1 instance)
NUMA node(s):                            1
NUMA node0 CPU(s):                       0-3
Vulnerability Gather data sampling:      Vulnerable: No microcode
Vulnerability Ghostwrite:                Not affected
Vulnerability Indirect target selection: Not affected
Vulnerability Itlb multihit:             KVM: Mitigation: Split huge pages
Vulnerability L1tf:                      Mitigation; PTE Inversion; VMX conditional cache flushes, SMT disabled
Vulnerability Mds:                       Mitigation; Clear CPU buffers; SMT disabled
Vulnerability Meltdown:                  Mitigation; PTI
Vulnerability Mmio stale data:           Mitigation; Clear CPU buffers; SMT disabled
Vulnerability Old microcode:             Not affected
Vulnerability Reg file data sampling:    Not affected
Vulnerability Retbleed:                  Mitigation; IBRS
Vulnerability Spec rstack overflow:      Not affected
Vulnerability Spec store bypass:         Mitigation; Speculative Store Bypass disabled via prctl
Vulnerability Spectre v1:                Mitigation; usercopy/swapgs barriers and __user pointer sanitization
Vulnerability Spectre v2:                Mitigation; IBRS; IBPB conditional; STIBP disabled; RSB filling; PBRSB-eIBRS Not affected; BHI Not affected
Vulnerability Srbds:                     Mitigation; Microcode
Vulnerability Tsa:                       Not affected
Vulnerability Tsx async abort:           Mitigation; TSX disabled
Vulnerability Vmscape:                   Mitigation; IBPB before exit to userspace
--------------------------------------------------


### Memory Usage ###
--------------------------------------------------
Running: free -h
               total        used        free      shared  buff/cache   available
Mem:            15Gi       5.8Gi       2.2Gi       1.0Gi       8.8Gi       9.7Gi
Swap:          8.0Gi          0B       8.0Gi
--------------------------------------------------


### PCI Devices (Filtered for GPU) ###
--------------------------------------------------
Command not found: lspci
--------------------------------------------------


### PCI Devices with Kernel Modules (Filtered for GPU) ###
--------------------------------------------------
Command not found: lspci
--------------------------------------------------


### Detailed Display Hardware Info ###
--------------------------------------------------
Running: sudo lshw -C display
sudo: lshw: command not found
--------------------------------------------------


### OpenGL / Renderer Information ###
--------------------------------------------------
Running: glxinfo -B
name of display: :0
display: :0  screen: 0
direct rendering: Yes
Extended renderer info (GLX_MESA_query_renderer):
    Vendor: Intel (0x8086)
    Device: Mesa Intel(R) HD Graphics 530 (SKL GT2) (0x1912)
    Version: 25.2.4
    Accelerated: yes
    Video memory: 15859MB
    Unified memory: yes
    Preferred profile: core (0x1)
    Max core profile version: 4.6
    Max compat profile version: 4.6
    Max GLES1 profile version: 1.1
    Max GLES[23] profile version: 3.2
OpenGL vendor string: Intel
OpenGL renderer string: Mesa Intel(R) HD Graphics 530 (SKL GT2)
OpenGL core profile version string: 4.6 (Core Profile) Mesa 25.2.4
OpenGL core profile shading language version string: 4.60
OpenGL core profile context flags: (none)
OpenGL core profile profile mask: core profile

OpenGL version string: 4.6 (Compatibility Profile) Mesa 25.2.4
OpenGL shading language version string: 4.60
OpenGL context flags: (none)
OpenGL profile mask: compatibility profile

OpenGL ES profile version string: OpenGL ES 3.2 Mesa 25.2.4
OpenGL ES profile shading language version string: OpenGL ES GLSL ES 3.20

--------------------------------------------------


### VA-API Information (Intel/AMD) ###
--------------------------------------------------
Command not found: vainfo
--------------------------------------------------


### NVIDIA System Management Interface (NVIDIA) ###
--------------------------------------------------
Command not found: nvidia-smi
--------------------------------------------------


### Loaded Kernel Modules (Filtered for GPU) ###
--------------------------------------------------
Running: lsmod | grep -E 'nvidia|amdgpu|i915|radeon'
amdgpu              15876096  0
amdxcp                 12288  1 amdgpu
gpu_sched              65536  1 amdgpu
drm_panel_backlight_quirks    12288  1 amdgpu
i915                 4816896  50
drm_buddy              32768  2 amdgpu,i915
radeon               2146304  2
drm_exec               16384  2 amdgpu,radeon
drm_suballoc_helper    16384  2 amdgpu,radeon
drm_ttm_helper         20480  2 amdgpu,radeon
ttm                   122880  4 amdgpu,radeon,drm_ttm_helper,i915
drm_display_helper    307200  3 amdgpu,radeon,i915
cec                    81920  3 drm_display_helper,amdgpu,i915
intel_gtt              32768  1 i915
i2c_algo_bit           24576  3 amdgpu,radeon,i915
video                  81920  4 dell_wmi,amdgpu,radeon,i915
crc16                  12288  2 amdgpu,ext4
--------------------------------------------------


### Linked Video/Encoding Libraries ###
--------------------------------------------------
Running: ldconfig -p | grep -i -E 'nvenc|nvencc|va|vdpau|v4l2'
ldconfig: Can't open cache file /nix/store/776irwlgfb65a782cxmyk61pck460fs9-glibc-2.40-66/etc/ld.so.cache
: No such file or directory
--------------------------------------------------


### Kernel Messages (DRM) ###
--------------------------------------------------
Running: dmesg | grep -i drm
dmesg: read kernel buffer failed: Operation not permitted
--------------------------------------------------


### Kernel Messages (NVIDIA) ###
--------------------------------------------------
Running: dmesg | grep -i nvidia
dmesg: read kernel buffer failed: Operation not permitted
--------------------------------------------------
```
