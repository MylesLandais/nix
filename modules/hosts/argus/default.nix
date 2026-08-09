{ inputs, lib, ... }:
let
  mkHostLib = import ../../flake-parts/_mk-host.nix { inherit inputs lib; };
  node = (import ../_deploy-nodes.nix { inherit inputs lib; }).argus;
in
{
  flake.nixosConfigurations.argus = mkHostLib.mkHost {
    name = "argus";
    inherit (node) modules;
    inherit (node) users;
    inherit (node) desktop;
  };
}
