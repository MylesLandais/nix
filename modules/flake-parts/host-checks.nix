# Expose every nixosConfiguration as a flake check so `nix flake check`
# builds all hosts. Uses config.flake (not self) to avoid infinite recursion.
{ config, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;
  system = "x86_64-linux";
in
{
  flake.checks.${system} = lib.mapAttrs' (
    name: nixos: lib.nameValuePair "host-${name}" nixos.config.system.build.toplevel
  ) config.flake.nixosConfigurations;
}
