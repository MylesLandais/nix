# Flake outputs that are not per-system flake-parts options.
{ config, inputs, ... }:
{
  flake = {
    # Public names for the module registry.
    nixosModules = config.flake.modules.nixos;
    homeManagerModules = config.flake.modules.homeManager;

    colmena = import ../../colmena.nix {
      inherit inputs;
      inherit (config.nodeBuilders) mkModules;
    };
  };
}
