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
