# Re-evaluate the locked flake for comparison only. Keep the actual source and
# all locked inputs so a changed consumed file still affects the derivation.
{ flakeRef, expectedRev }:
let
  source = builtins.getFlake flakeRef;
  definition = import (source.outPath + "/flake.nix");
  inputs = source.inputs // {
    self = comparison;
  };
  outputs = definition.outputs inputs;
  comparison =
    source
    // outputs
    // {
      inherit inputs outputs;
      rev = "0000000000000000000000000000000000000000";
      shortRev = "0000000";
    };
in
assert source.rev == expectedRev;
comparison.nixosConfigurations.installerIso.config
