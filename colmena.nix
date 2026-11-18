{
  inputs,
  mkModules ? inputs.self.lib.mkModules,
}:
let
  lib = inputs.nixpkgs.lib;
  deployNodes = import ./modules/hosts/_deploy-nodes.nix { inherit inputs lib; };

  mkColmenaNode = name: node: {
    deployment = {
      targetHost = node.targetHost or name;
      targetUser = "warby";
      buildOnTarget = false;
      tags = node.tags or [ ];
    };
    imports = mkModules {
      inherit (node) modules;
      inherit (node) users;
      desktop = node.desktop or false;
    };
  };
in
{
  meta = {
    # Colmena exposes these inputs to modules supplied by downstream hive consumers.
    specialArgs = { inherit inputs; };
    nixpkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
  };

  defaults = _: {
    deployment = {
      targetUser = "warby";
      buildOnTarget = false;
    };
  };
}
// lib.mapAttrs mkColmenaNode deployNodes
