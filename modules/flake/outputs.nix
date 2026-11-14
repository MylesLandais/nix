# Flake outputs that are not per-system flake-parts options.
{ config, inputs, ... }:
{
  flake = {
    # Public names for the module registry.
    nixosModules = config.flake.modules.nixos;
    homeManagerModules = config.flake.modules.homeManager;

    # OCI ownership is external; preserve existing consumer output names.
    nixosConfigurations = {
      inherit (inputs.nebula-infra.nixosConfigurations) stage-db stage-edge;
    };
    devShells = inputs.nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: {
      forgejo = inputs.nebula-infra.devShells.${system}.forgejo;
    });

    colmena = import ../../colmena.nix { inherit inputs; };
  };
}
