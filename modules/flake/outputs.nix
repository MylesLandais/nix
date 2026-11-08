# Flake outputs that are not per-system flake-parts options.
{ config, inputs, ... }:
{
  flake = {
    # Public names for the module registry.
    nixosModules = config.flake.modules.nixos;
    homeManagerModules = config.flake.modules.homeManager;

    # OpenTofu/compose tooling for infra/forgejo. Defined directly rather than
    # through perSystem because `systems` is x86_64-linux only. Moves to
    # nebula-infra in Phase 6.
    devShells = inputs.nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (
      system:
      let
        pkgs = import inputs.nixpkgs { inherit system; };
      in
      {
        forgejo = pkgs.mkShell {
          packages = with pkgs; [
            opentofu
            docker-compose
            openssl
            jq
            postgresql_16
            skopeo
          ];
        };
      }
    );

    colmena = import ../../colmena.nix { inherit inputs; };
  };
}
