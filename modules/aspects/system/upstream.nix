# Upstream NixOS modules, registered so hosts compose them through the same
# registry as local modules. Importing them raw would also put their
# definitions at a different depth in the module tree than registry modules,
# which reorders merged lists (e.g. nix.settings.substituters).
{ inputs, ... }:
{
  flake.modules.nixos.chaotic = inputs.chaotic.nixosModules.default;
}
