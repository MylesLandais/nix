{ inputs, lib, ... }:
let
  mkHostLib = import ../../flake-parts/_mk-host.nix { inherit inputs lib; };
  node = (import ../_deploy-nodes.nix { inherit inputs lib; }).lacie;
in
{
  flake.nixosConfigurations.lacie = mkHostLib.mkHost {
    name = "lacie";
    inherit (node) modules;
    inherit (node) users;
    inherit (node) desktop;
    extraSpecialArgs = node.extraSpecialArgs or { };
  };
}
