{ inputs, ... }:
{
  perSystem =
    { config, pkgs, ... }:
    {
      devShells.default = pkgs.mkShell {
        packages = [
          config.treefmt.build.wrapper
          inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
          pkgs.colmena
          pkgs.deadnix
          pkgs.git
          pkgs.nix-tree
          pkgs.nixfmt
          pkgs.python3
          pkgs.statix
        ];
      };
    };
}
