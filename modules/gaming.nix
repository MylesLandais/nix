{ config, lib, pkgs, ... }:

{
  # OpenGL
  hardware.opengl = {
    enable = true;
    driSupport = true;
    driSupport32Bit = true;
  };

  # NVIDIA drivers (optimized for gaming)
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;  # Disable for better performance
    powerManagement.finegrained = true;
    open = false;  # Use proprietary for stability
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  # Steam
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  # Gamescope for Steam Deck-like experience
  programs.gamescope.enable = true;

  # RetroArch for emulation (Batocera-like)
  programs.retroarch.enable = true;
  programs.gamemode.enable = true;

  # Additional gaming tools
  environment.systemPackages = with pkgs; [
    gamescope
    retroarchFull
    lutris
    heroic-games-launcher
    wineWowPackages.stable
    protontricks
    mangohud  # For performance overlay
    gamemode
  ];

  # Enable fuse for flatpaks/steam
  services.fuse.userAllowOther.enable = true;

  # Performance: Enable early KMS
  boot.kernelParams = [ "nvidia_drm.modeset=1" ];

  # 32-bit support
  system.replaceRuntimeDependencies = true;  # For better compatibility
}