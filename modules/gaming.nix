{ config, lib, pkgs, ... }:

{
  # OpenGL
  hardware.opengl = {
    enable = true;
  };

  # Intel graphics support (for dell-potato)
  hardware.opengl.extraPackages = with pkgs; [
    intel-media-driver
    vaapiIntel
  ];

  services.xserver.videoDrivers = [ "modesetting" ];

  # Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # Gamescope for Steam Deck-like experience
  programs.gamescope.enable = true;

  # RetroArch for emulation (Batocera-like)
  programs.gamemode.enable = true;

  # Additional gaming tools
  environment.systemPackages = with pkgs; [
    # Gaming tools
    gamescope
    lutris
    heroic
    wineWowPackages.stable
    protontricks
    mangohud  # For performance overlay
    gamemode

    # RetroArch and cores
    retroarchFull
    libretro.swanstation
    libretro.beetle-psx

    # Standalone emulators
    mgba
    snes9x-gtk
    mednafen
    pcsx2
    rpcs3
  ];

  # Enable fuse for flatpaks/steam
  programs.fuse.userAllowOther = true;

  # Performance: Enable early KMS
  # No specific kernel params for Intel

  # 32-bit support
}