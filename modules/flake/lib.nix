# flake.lib: plain functions shared by NixOS and home-manager modules.
# Built from inputs.nixpkgs.lib, the same lib the hosts evaluate with, rather
# than flake-parts' own lib.
{ inputs, ... }:
{
  flake.lib = {
    chromiumBrowsers = import ./_chromium-browsers.nix { inherit (inputs.nixpkgs) lib; };
    # Shared module bodies of the Dell 7050 cluster nodes (hosts/_dell7050).
    dell7050 = import ../hosts/_dell7050;
    # Host builders (see _mk-host.nix).
    inherit
      (import ./_mk-host.nix {
        inherit inputs;
        inherit (inputs.nixpkgs) lib;
      })
      mkHost
      mkModules
      ;
  };
}
