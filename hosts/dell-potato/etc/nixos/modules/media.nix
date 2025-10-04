{ config, pkgs, ... }:

{
  # Media Ripping and Playback Configuration
  # This module contains all media-related packages and configuration

  # Allow unfree packages (needed for some DVD decryption libraries; handled in flake.nix)

  # Media packages
  environment.systemPackages = with pkgs; [
    # Core media ripping tools
    makemkv          # DVD/Blu-ray to MKV converter
    handbrake        # Video transcoding and compression
    libdvdcss        # DVD decryption library
    libdvdnav        # DVD navigation library
    libdvdread       # DVD reading library
    lsdvd            # DVD information tool
    mkvtoolnix-cli   # MKV manipulation tools (CLI)
    
    # Media players (mpv preferred over VLC)
    mpv              # Lightweight, customizable media player
    vlc              # Fallback media player
    
    # Additional media utilities
    mediainfo        # Media file information
    ffmpeg           # Video/audio processing
    dvdbackup        # DVD backup utility
    
    # Optional: GUI tools for desktop use
    # mkvtoolnix     # GUI version of MKV tools
    # handbrake      # GUI version (if different from CLI)
  ];

  # Hardware support for optical drives
  hardware = {
    # Enable redistributable firmware for hardware support (avoids unfree)
    enableRedistributableFirmware = true;
    
    # Graphics/video support
    graphics.enable = true;
  };

  # Services for media handling
  services = {
    # Enable udisks2 for automounting USB/optical drives
    udisks2.enable = true;
  };

  # User permissions for media operations
  users.users.warby.extraGroups = [ 
    "cdrom"     # Access to optical drives
    "optical"   # Additional optical drive access
    "video"     # Video device access
    "audio"     # Audio device access
  ];

  # Create media directories with proper permissions
  systemd.tmpfiles.rules = [
    "d /media 0755 warby users -"
    "d /media/movies 0755 warby users -"
    "d /media/tv 0755 warby users -"
    "d /media/ripping 0755 warby users -"
    "d /media/ripping/temp 0755 warby users -"
  ];

  # Audio configuration (if not already configured elsewhere)
  # Note: This assumes PipeWire is already configured in main config
  # hardware.pulseaudio.enable = false;
  # security.rtkit.enable = true;
  # services.pipewire = {
  #   enable = true;
  #   alsa.enable = true;
  #   alsa.support32Bit = true;
  #   pulse.enable = true;
  # };
}
