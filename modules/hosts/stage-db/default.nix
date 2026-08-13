{ inputs, lib, ... }:
let
  mkHostLib = import ../../flake-parts/_mk-host.nix { inherit inputs lib; };
in
{
  # See modules/hosts/stage-edge/default.nix for why these hosts sit outside
  # _deploy-nodes.nix / colmena.
  flake.nixosConfigurations.stage-db = mkHostLib.mkHost {
    name = "stage-db";
    system = "aarch64-linux";
    modules = [ inputs.self.nixosModules.stageDb ];
    users = { };
  };
}
