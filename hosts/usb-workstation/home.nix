# USB Workstation home-manager config.
# Inherits the full cerberus environment and overrides Hyprland for portability.
{ lib, ... }:
{
  imports = [ ../../home.nix ];

  # Single portable monitor: preferred resolution, auto position.
  # Overrides the cerberus 4-monitor layout in hypr.nix.
  wayland.windowManager.hyprland.settings = {
    monitor = lib.mkForce [
      ",preferred,auto,1"
    ];

    workspace = lib.mkForce [
      "1,default:true"
      "2"
      "3"
      "4"
      "5"
      "6"
      "7"
      "8"
      "9"
      "10"
    ];

    # Remove NVIDIA-specific env vars; keep Wayland essentials.
    env = lib.mkForce [
      "XDG_SESSION_TYPE,wayland"
      "NIXOS_OZONE_WL,1"
      "ELECTRON_OZONE_PLATFORM_HINT,auto"
      "XDG_CURRENT_DESKTOP,Hyprland"
      "XDG_SESSION_DESKTOP,Hyprland"
    ];
  };
}
