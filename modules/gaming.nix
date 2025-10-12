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
  # Graphics support for 3D gaming
  hardware.graphics = {
    enable = true;
  };

  # Intel graphics support (optimized for dell-potato)
  hardware.graphics.extraPackages = with pkgs; [
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
    # Temporarily disabled cores due to CMake compatibility issues:
    # libretro.thepowdertoy
    # libretro.citra
    # libretro.dolphin
    # libretro.tic80
    # libretro.mgba
    # Temporarily disabled cores due to CMake compatibility issues:
    # libretro.thepowdertoy
    # libretro.mgba             # Game Boy Advance - temporarily disabled due to CMake compatibility issue
    # libretro.citra            # 3DS emulator - temporarily disabled due to CMake compatibility issue
    # libretro.dolphin          # Wii/GameCube emulator - temporarily disabled due to CMake compatibility issue
    # libretro.genesis-plus-gx  # Genesis/Mega Drive - temporarily disabled due to CMake compatibility issue
    # libretro.snes9x           # Super Nintendo - temporarily disabled due to CMake compatibility issue
    # libretro.snes9x2002       # Super Nintendo - temporarily disabled due to CMake compatibility issue
    # libretro.snes9x2005       # Super Nintendo - temporarily disabled due to CMake compatibility issue
    # libretro.snes9x2005-plus  # Super Nintendo - temporarily disabled due to CMake compatibility issue
    # libretro.snes9x2010       # Super Nintendo - temporarily disabled due to CMake compatibility issue
    # libretro.fmsx             # MSX - temporarily disabled due to CMake compatibility issue
    # libretro.mame2003-plus    # Arcade - temporarily disabled due to CMake compatibility issue
    # libretro.mame2000         # Arcade - temporarily disabled due to CMake compatibility issue
    # libretro.mame2010         # Arcade - temporarily disabled due to CMake compatibility issue
    # libretro.mame2015         # Arcade - temporarily disabled due to CMake compatibility issue
    # libretro.fbneo            # Arcade - temporarily disabled due to CMake compatibility issue
    # libretro.fbalpha2012      # Arcade - temporarily disabled due to CMake compatibility issue
    # libretro.mame2003         # Arcade - temporarily disabled due to CMake compatibility issue
    # libretro.opera            # 3DO - temporarily disabled due to CMake compatibility issue
    # libretro.tic80            # Fantasy console - temporarily disabled due to CMake compatibility issue
    # libretro.picodrive        # Sega - temporarily disabled due to CMake compatibility issue

    # Standalone emulators
    # mgba          # Game Boy Advance - temporarily disabled due to CMake compatibility issue
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