{ inputs, ... }:
{
  flake.nixosModules.desktops = {
    imports = [
      "${inputs.self}/modules/_features/desktops/hyprland/system.nix"
      "${inputs.self}/modules/_features/desktops/niri/system.nix"
      "${inputs.self}/modules/_features/desktops/xfce/system.nix"
      "${inputs.self}/modules/_features/kali/system.nix"
    ];
  };
}
