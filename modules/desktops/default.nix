# nixos.desktops: the NixOS halves of every desktop. Each one is gated by
# host.desktop / host.kali.enable inside its own module, so hosts import the
# whole set.
{ config, ... }:
{
  flake.modules.nixos.desktops = {
    imports = [
      config.flake.modules.nixos.hyprland
      config.flake.modules.nixos.niri
      config.flake.modules.nixos.xfce
      config.flake.modules.nixos.kali
    ];
  };
}
