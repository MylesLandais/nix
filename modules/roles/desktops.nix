# nixos.desktops: the NixOS half of the desktop session. Hyprland is the only
# one; its Home Manager half comes in through homeManager.base.
{ config, ... }:
{
  flake.modules.nixos.desktops = {
    imports = [ config.flake.modules.nixos.hyprland ];
  };
}
