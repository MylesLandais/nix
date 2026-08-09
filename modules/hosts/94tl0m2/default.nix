{ inputs, lib, ... }:
let
  mkHostLib = import ../../flake-parts/_mk-host.nix { inherit inputs lib; };
  node = (import ../_deploy-nodes.nix { inherit inputs lib; })."94tl0m2";
in
{
  flake.nixosConfigurations."94tl0m2" = mkHostLib.mkHost {
    name = "94tl0m2";
    inherit (node) modules;
    inherit (node) users;
    inherit (node) desktop;
  };
}
