# Expose every nixosConfiguration as a flake check so `nix flake check`
# builds all hosts. Uses config.flake (not self) to avoid infinite recursion.
#
# Hosts are filed under their OWN system rather than a hardcoded x86_64-linux:
# the OCI hosts (stage-edge, stage-db) are aarch64, and filing an aarch64
# toplevel under flake.checks.x86_64-linux makes `nix flake check` try to build
# it as a native x86_64 derivation and fail.
{ config, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;

  hosts = config.flake.nixosConfigurations;
  # Read the platform off the instantiated pkgs, not `config.nixpkgs.hostPlatform`:
  # mkHost passes `system` straight to nixosSystem, so hostPlatform is never
  # explicitly defined and accessing it throws "option ... has no value defined".
  systemOf = nixos: nixos.pkgs.stdenv.hostPlatform.system;

  checksFor =
    system:
    lib.mapAttrs' (name: nixos: lib.nameValuePair "host-${name}" nixos.config.system.build.toplevel) (
      lib.filterAttrs (_: nixos: systemOf nixos == system) hosts
    );
in
{
  flake.checks = lib.genAttrs (lib.unique (lib.mapAttrsToList (_: systemOf) hosts)) checksFor;
}
