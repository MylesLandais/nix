# Hosts defined by the deploy-node table (_deploy-nodes.nix, which colmena.nix
# also reads) are built here, one mkHost per entry. Hosts with their own
# wiring (cerberus, 7PZSZY2, the OCI hosts, the installer) keep a default.nix
# in their directory.
{ inputs, lib, ... }:
let
  mkHostLib = import ../flake/_mk-host.nix { inherit inputs lib; };
  deployNodes = import ./_deploy-nodes.nix { inherit inputs lib; };
  # Migrated to the table so far (M-301..M-303).
  tableHosts = [
    "kali-vm"
    "lacie"
    "argus"
    "94tl0m2"
    "95qmom2"
  ];
in
{
  flake.nixosConfigurations = lib.genAttrs tableHosts (
    name:
    let
      node = deployNodes.${name};
    in
    mkHostLib.mkHost {
      inherit name;
      inherit (node) modules users desktop;
      extraSpecialArgs = node.extraSpecialArgs or { };
    }
  );
}
