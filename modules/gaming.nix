# ============================================================================
# Gaming and Emulation Module
# ============================================================================
#
# This module configures a comprehensive gaming environment with Steam,
# emulators, and performance optimizations. Designed for both modern gaming
# and retro gaming through various emulation platforms.
#
# HARDWARE SUPPORT:
# =================
# - Intel Graphics: VAAPI acceleration, media driver support
# - OpenGL: Enabled for 3D gaming
# - Video Driver: Modesetting for Intel integrated graphics
#
# STEAM CONFIGURATION:
# ====================
# - Steam client with remote play support
# - Firewall ports open for remote play and dedicated servers
# - Proton compatibility layer for Windows games
#
# EMULATION SUITE:
# ================
# - RetroArch: Full-featured emulator frontend with multiple cores
#   - SwanStation: PS1 emulator (modern)
#   - Beetle PSX: PS1 emulator (accurate)
# - Standalone Emulators:
#   - mGBA: Game Boy Advance
#   - Snes9x: Super Nintendo
#   - Mednafen: Multi-system (NES, SNES, GB, GBA)
#   - PCSX2: PlayStation 2
#   - RPCS3: PlayStation 3
#
# GAMING TOOLS:
# =============
# - Gamescope: Steam Deck-like compositing for better performance
# - Gamemode: CPU/GPU performance optimization
# - Lutris: Game library manager for non-Steam games
# - Heroic: Epic Games and GOG launcher
# - Wine: Windows compatibility layer
# - Protontricks: Winetricks for Proton games
# - MangoHud: FPS and performance overlay
#
# PERFORMANCE FEATURES:
# ====================
# - FUSE support for AppImages and Steam
# - Early KMS for faster graphics initialization
# - 32-bit library support for legacy games
#
# USAGE:
# ======
# Import this module in host configurations (e.g., dell-potato) to enable
# gaming capabilities. Use gamescope with: gamescope -w 1920 -h 1080 -- %command%
# Enable gamemode with: gamemoderun %command%
#
# ============================================================================

{ config, lib, pkgs, ... }:

{
  # OpenGL support for 3D gaming
  hardware.opengl = {
    enable = true;
  };

  # Intel graphics support (optimized for dell-potato)
  hardware.opengl.extraPackages = with pkgs; [
    intel-media-driver  # Hardware-accelerated video decoding
    vaapiIntel         # VAAPI support for Intel GPUs
  ];

  # Video driver configuration
  services.xserver.videoDrivers = [ "modesetting" ];

  # Steam gaming platform
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;      # Allow remote play connections
    dedicatedServer.openFirewall = true; # Allow dedicated server hosting
  };

  # Gamescope for composited gaming experience
  programs.gamescope.enable = true;

  # Gamemode for performance optimization
  programs.gamemode.enable = true;

  # Comprehensive gaming and emulation toolset
  environment.systemPackages = with pkgs; [
    # Core gaming tools
    gamescope      # Compositor for gaming
    lutris         # Game library manager
    heroic         # Epic/GOG game launcher
    wineWowPackages.stable  # Windows compatibility
    protontricks   # Winetricks for Proton
    mangohud       # Performance overlay
    gamemode       # CPU/GPU optimization

    # RetroArch ecosystem
    retroarchFull              # Full RetroArch with all cores
    libretro.swanstation       # PS1 core (modern)
    libretro.beetle-psx        # PS1 core (accurate)

    # Standalone emulators
    mgba          # Game Boy Advance
    snes9x-gtk    # Super Nintendo
    mednafen      # Multi-system emulator
    pcsx2         # PlayStation 2
    rpcs3         # PlayStation 3
  ];

  # Enable FUSE for AppImages and Steam compatibility
  programs.fuse.userAllowOther = true;

  # Performance optimizations (Intel-specific)
  # Early KMS enabled via kernel params in host config
}