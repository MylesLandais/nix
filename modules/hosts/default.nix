# Hosts defined by the deploy-node table (_deploy-nodes.nix, which colmena.nix
# also reads) are built here, one mkHost per entry. Hosts with their own
# wiring (cerberus, 7PZSZY2, the OCI hosts, the installer) keep a default.nix
# in their directory.
{ inputs, lib, ... }:
let
  mkHostLib = import ../flake/_mk-host.nix { inherit inputs lib; };
  deployNodes = import ./_deploy-nodes.nix { inherit inputs lib; };
in
{
  flake.nixosConfigurations = lib.mapAttrs (
    name: node:
    mkHostLib.mkHost {
      inherit name;
      inherit (node) modules users desktop;
      extraSpecialArgs = node.extraSpecialArgs or { };
    }
  ) deployNodes;
}
