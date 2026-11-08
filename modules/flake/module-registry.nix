# checks.<system>.module-registry: the module registry must match
# docs/migration/registry.json. Renaming, adding or removing a module means
# updating that file in the same commit, so module identities never change by
# accident (for example when a file is moved).
{ config, lib, ... }:
let
  actual = {
    nixos = builtins.attrNames config.flake.modules.nixos;
    homeManager = builtins.attrNames config.flake.modules.homeManager;
    nixosModules = builtins.attrNames config.flake.nixosModules;
    homeManagerModules = builtins.attrNames config.flake.homeManagerModules;
  };
  expected = lib.importJSON ../../docs/migration/registry.json;
  diff = lib.concatStringsSep "\n" (
    lib.concatMap (
      ns:
      let
        a = actual.${ns};
        e = expected.${ns} or [ ];
      in
      map (n: "+ ${ns}.${n} (not in registry.json)") (lib.subtractLists e a)
      ++ map (n: "- ${ns}.${n} (missing from the flake)") (lib.subtractLists a e)
    ) (builtins.attrNames actual)
  );
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.module-registry = pkgs.runCommand "module-registry" { inherit diff; } ''
        if [ -n "$diff" ]; then
          echo "module registry differs from docs/migration/registry.json:"
          echo "$diff"
          exit 1
        fi
        touch $out
      '';
    };
}
