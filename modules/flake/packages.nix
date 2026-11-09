# Custom packages: one directory per package under pkgs/ (pkgs/<name>/package.nix),
# exposed as the default overlay. Packages are called with prev.callPackage,
# which (like any callPackage) resolves their dependencies from the final set.
_: {
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
}
