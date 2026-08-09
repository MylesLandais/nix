{ inputs, lib, ... }:
let
  mkHostLib = import ../../flake-parts/_mk-host.nix { inherit inputs lib; };
  node = (import ../_deploy-nodes.nix { inherit inputs lib; }).kali-vm;
in
{
  flake.nixosConfigurations.kali-vm = mkHostLib.mkHost {
    name = "kali-vm";
    inherit (node) modules;
    inherit (node) users;
    inherit (node) desktop;
    extraSpecialArgs = node.extraSpecialArgs or { };
  };
}
