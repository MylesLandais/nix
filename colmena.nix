{ inputs }:
let
  lib = inputs.nixpkgs.lib;
  mkHostLib = import ./modules/flake-parts/_mk-host.nix { inherit inputs lib; };
  deployNodes = import ./modules/hosts/_deploy-nodes.nix { inherit inputs lib; };

  mkColmenaNode = name: node: {
    deployment = {
      targetHost = node.targetHost or name;
      targetUser = "warby";
      buildOnTarget = false;
      tags = node.tags or [ ];
    };
    imports = mkHostLib.mkModules {
      inherit (node) modules;
      inherit (node) users;
      desktop = node.desktop or false;
      extraSpecialArgs = node.extraSpecialArgs or { };
    };
  };
in
{
  meta = {
    nixpkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
    specialArgs = { inherit inputs; };
  };

  defaults = _: {
    deployment = {
      targetUser = "warby";
      buildOnTarget = false;
    };
  };
}
// lib.mapAttrs mkColmenaNode deployNodes
