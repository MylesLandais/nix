# Migration harness: `nix run .#migration -- <capture|verify|audit|inventory>`.
# See docs/migration/README.md. snapshot.nix is wrapped as a tiny flake so it
# can be loaded with getFlake in pure evaluation mode.
{
  perSystem =
    { pkgs, ... }:
    let
      harnessFlake = pkgs.runCommand "migration-harness" { } ''
        mkdir $out
        cp ${../../scripts/migration/snapshot.nix} $out/snapshot.nix
        cp ${../../scripts/migration/installer-comparison.nix} $out/installer-comparison.nix
        cp ${../../scripts/migration/closure-roots.nix} $out/closure-roots.nix
        echo '{ outputs = _: { lib = import ./snapshot.nix; }; }' > $out/flake.nix
      '';
      migration = pkgs.writeShellApplication {
        name = "migration";
        runtimeInputs = with pkgs; [
          coreutils
          git
          gnugrep
          gnused
          jq
          findutils
          gawk
          nix-diff
          python3
          yq-go
        ];
        text = ''
          export HARNESS_FLAKE=${harnessFlake}
          export CLOSURE_COMPARE=${../../scripts/migration/compare-closures.py}
        ''
        + builtins.readFile ../../scripts/migration/drv-equiv.sh
        + builtins.readFile ../../scripts/migration/migration.sh;
      };
    in
    {
      packages.migration = migration;
      apps.migration = {
        type = "app";
        program = "${migration}/bin/migration";
      };
    };
}
