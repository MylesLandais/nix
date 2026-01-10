{
  config,
  lib,
  pkgs,
  ...
}:

let
  # Wrapper script for Sunshine streaming via gamescope (iPad Mini native resolution)
  steam-sunshine = pkgs.writeShellScriptBin "steam-sunshine" ''
    # Launch Steam Big Picture inside gamescope for clean Sunshine capture
    # Resolution: iPad Mini native (2266x1488 @ 60Hz)
    exec gamescope \
      --adaptive-sync \
      --steam \
      --mangoapp \
      -W 2266 -H 1488 \
      -w 2266 -h 1488 \
      -r 60 \
      -f \
      --rt \
      -- steam -bigpicture
  '';
in
{
  # Graphics support for 3D gaming
  # hardware.graphics = {
  #   enable = true;
  #  extraPackages = with pkgs; [
  #    intel-media-driver # Hardware-accelerated video decoding
  #    vaapiIntel # VAAPI support for Intel GPUs
  #  ];
  #};

  # Video driver configuration (updated for NVIDIA compatibility)
  services.xserver.videoDrivers = [ "nvidia" ]; # Use NVIDIA drivers as per previous configuration

  # Steam gaming platform
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Allow remote play connections
    dedicatedServer.openFirewall = true; # Allow dedicated server hosting
  };
  # Gamescope for composited gaming experience
  programs.gamescope.enable = true;
  # Gamemode for performance optimization
  programs.gamemode.enable = true;
  # Enable FUSE for AppImages and Steam compatibility
  programs.fuse.userAllowOther = true;

  # Comprehensive gaming and emulation toolset
  environment.systemPackages = with pkgs; [
    # Core gaming tools
    steam-sunshine # Gamescope wrapper for Sunshine streaming
    gamescope # Compositor for gaming
    lutris # Game library manager
    heroic # Epic/GOG game launcher
    wineWowPackages.stable # Windows compatibility
    protontricks # Winetricks for Proton
    mangohud # Performance overlay
    gamemode # CPU/GPU optimization
    runelite
    # RetroArch with minimal cores (bsnes and mgba)
    (retroarch.overrideAttrs (old: {
      passthru = old.passthru // {
        cores = with libretro; [
          bsnes # Super Nintendo core
          mgba # Game Boy Advance core
        ];
      };
    }))
    libretro.swanstation # PS1 core (modern)
    libretro.beetle-psx # PS1 core (accurate)
    # snes9x-gtk # Super Nintendo (Temporarily removed to unblock system rebuild)
    mednafen # Multi-system emulator
    pcsx2 # PlayStation 2
    rpcs3 # PlayStation 3
          # Temporarily disabled due to build failure:
          # Error: builder failed with exit code 2 (C++ compilation errors)
    ryubing
  ];
}
