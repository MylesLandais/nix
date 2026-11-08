{ inputs, ... }:
{
  flake.modules.nixos.desktops = {
    imports = [
      "${inputs.self}/modules/desktops/hyprland/_system.nix"
      "${inputs.self}/modules/desktops/niri/_system.nix"
      "${inputs.self}/modules/desktops/xfce/_system.nix"
      "${inputs.self}/modules/_features/kali/system.nix"
    ];
  };
}
