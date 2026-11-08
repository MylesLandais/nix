# Host validation outputs, split so `nix flake check` stays cheap.
#
# checks.<system>.host-<name>
#   Evaluation-only. Records the host's toplevel .drvPath in a tiny text file,
#   which forces the full NixOS evaluation (assertions, option types, module
#   errors) without building any closure. Safe on a free CI runner.
#
# packages.<system>.host-<name>
#   The real system closure (config.system.build.toplevel). Opt-in: build it
#   explicitly (`nix build .#host-cerberus`) or from a dedicated builder/cache
#   job. Never part of `nix flake check`.
#
# Both are filed under each host's OWN system rather than a hardcoded
# x86_64-linux: the OCI hosts (stage-edge, stage-db) are aarch64, and filing an
# aarch64 output under x86_64-linux makes Nix try to build it natively and fail.
# Uses config.flake (not self) to avoid infinite recursion.
{ config, inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;

  hosts = config.flake.nixosConfigurations;
  # Read the platform off the instantiated pkgs, not `config.nixpkgs.hostPlatform`:
  # mkHost passes `system` straight to nixosSystem, so hostPlatform is never
  # explicitly defined and accessing it throws "option ... has no value defined".
  systemOf = nixos: nixos.pkgs.stdenv.hostPlatform.system;

  systems = lib.unique (lib.mapAttrsToList (_: systemOf) hosts);

  forSystem =
    system: f:
    lib.mapAttrs' (name: nixos: lib.nameValuePair "host-${name}" (f nixos)) (
      lib.filterAttrs (_: nixos: systemOf nixos == system) hosts
    );
in
{
  flake.checks = lib.genAttrs systems (
    system:
    forSystem system (
      # Discard the string context so the check records the path without
      # depending on (and therefore building) the toplevel it points at.
      nixos:
      nixos.pkgs.writeText "host-drv" (
        builtins.unsafeDiscardStringContext nixos.config.system.build.toplevel.drvPath + "\n"
      )
    )
  );

  flake.packages = lib.genAttrs systems (
    system: forSystem system (nixos: nixos.config.system.build.toplevel)
  );
}
