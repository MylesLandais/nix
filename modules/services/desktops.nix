{ inputs, ... }:
{
  flake.nixosModules.desktops = {
    imports = [
      "${inputs.self}/modules/features/desktops/niri/system.nix"
      "${inputs.self}/modules/features/desktops/xfce/system.nix"
      "${inputs.self}/modules/features/kali/system.nix"
    ];
  };
}
