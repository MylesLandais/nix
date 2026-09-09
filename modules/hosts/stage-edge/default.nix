{ inputs, lib, ... }:
let
  mkHostLib = import ../../flake-parts/_mk-host.nix { inherit inputs lib; };
in
{
  # First aarch64 host in the repo. `system` has always been a mkHost argument
  # (defaulting to x86_64-linux) but no caller had ever set it.
  #
  # Not registered in modules/hosts/_deploy-nodes.nix on purpose: that registry
  # feeds colmena.nix, whose meta.nixpkgs is pinned to x86_64-linux. These hosts
  # are managed with plain `nixos-rebuild --target-host` instead.
  flake.nixosConfigurations.stage-edge = mkHostLib.mkHost {
    name = "stage-edge";
    system = "aarch64-linux";
    modules = [ inputs.self.modules.nixos.stageEdge ];
    users = { };
  };
}
