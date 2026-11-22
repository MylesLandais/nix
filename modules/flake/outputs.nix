# Flake outputs that are not per-system flake-parts options.
{ config, ... }:
{
  flake = {
    # Public names for the module registry.
    nixosModules = config.flake.modules.nixos;
    homeManagerModules = config.flake.modules.homeManager;
  };
}
