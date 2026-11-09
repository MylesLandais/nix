# Custom packages: one directory per package under pkgs/ (pkgs/<name>/package.nix),
# exposed as the default overlay. Packages are called with prev.callPackage,
# which (like any callPackage) resolves their dependencies from the final set.
{ config, inputs, ... }:
{
  flake.overlays.default =
    _final: prev:
    prev.lib.packagesFromDirectoryRecursive {
      inherit (prev) callPackage;
      directory = ../../pkgs;
    }
    // {
      # deepseek-harness was written against `prev` directly, so its inputs
      # (coreutils, bash, nodejs, …) come from the set as it stands where this
      # overlay is applied, not from the final set. Keep that exactly: a later
      # overlay on cerberus replaces coreutils.
      deepseek-harness = prev.lib.callPackageWith prev ../../pkgs/deepseek-harness/package.nix { };
    };

  # packages.<system>.<name> for every package in pkgs/, built from the same
  # overlay the hosts use. `nix flake check` evaluates them; CI builds none of
  # them (several are network FODs or large binary repacks).
  perSystem =
    { system, ... }:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ config.flake.overlays.default ];
      };
    in
    {
      packages = inputs.nixpkgs.lib.getAttrs (builtins.attrNames (builtins.readDir ../../pkgs)) pkgs;
    };
}
