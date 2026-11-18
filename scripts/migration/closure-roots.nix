{
  flakeRef,
  expectedRev,
  hosts ? "all",
}:
let
  flake = builtins.getFlake flakeRef;
  inherit (flake.inputs.nixpkgs) lib;
  names =
    if hosts == "all" then builtins.attrNames flake.nixosConfigurations else lib.splitString "," hosts;
  roots =
    name:
    let
      cfg =
        if name == "installerIso" then
          import ./installer-comparison.nix { inherit flakeRef expectedRev; }
        else
          flake.nixosConfigurations.${name}.config;
      pathOf = drv: builtins.unsafeDiscardStringContext drv.outPath;
    in
    {
      system = pathOf cfg.system.build.toplevel;
    }
    // lib.optionalAttrs (name == "installerIso") { iso = pathOf cfg.system.build.isoImage; }
    // lib.mapAttrs' (
      user: home: lib.nameValuePair "home/${user}" (pathOf home.home.activationPackage)
    ) (cfg.home-manager.users or { });
in
assert flake.rev == expectedRev;
{
  profiles = lib.genAttrs names roots;
}
