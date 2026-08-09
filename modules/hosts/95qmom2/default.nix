{ inputs, lib, ... }:
let
  mkHostLib = import ../../flake-parts/_mk-host.nix { inherit inputs lib; };
  node = (import ../_deploy-nodes.nix { inherit inputs lib; })."95qmom2";
in
{
  flake.nixosConfigurations."95qmom2" = mkHostLib.mkHost {
    name = "95qmom2";
    inherit (node) modules;
    inherit (node) users;
    inherit (node) desktop;
  };
}
