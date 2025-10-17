{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Graphics support for 3D gaming
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # Hardware-accelerated video decoding
      vaapiIntel # VAAPI support for Intel GPUs
    ];
  };

  # Video driver configuration
  services.xserver.videoDrivers = [ "modesetting" ];

  # Steam gaming platform
  programs = {
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Allow remote play connections
      dedicatedServer.openFirewall = true; # Allow dedicated server hosting
    };
    # Gamescope for composited gaming experience
    gamescope.enable = true;
    # Gamemode for performance optimization
    gamemode.enable = true;
    # Enable FUSE for AppImages and Steam compatibility
    fuse.userAllowOther = true;
  };

  # Comprehensive gaming and emulation toolset
  environment.systemPackages = with pkgs; [
    # Core gaming tools
    gamescope # Compositor for gaming
    lutris # Game library manager
    heroic # Epic/GOG game launcher
    wineWowPackages.stable # Windows compatibility
    protontricks # Winetricks for Proton
    mangohud # Performance overlay
    gamemode # CPU/GPU optimization

    # RetroArch ecosystem
    retroarchFull # Full RetroArch with all cores
    libretro.swanstation # PS1 core (modern)
    libretro.beetle-psx # PS1 core (accurate)
    snes9x-gtk # Super Nintendo
    mednafen # Multi-system emulator
    pcsx2 # PlayStation 2
    rpcs3 # PlayStation 3
  ];
}
