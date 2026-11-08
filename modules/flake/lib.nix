# flake.lib: plain functions shared by NixOS and home-manager modules.
# Built from inputs.nixpkgs.lib, the same lib the hosts evaluate with, rather
# than flake-parts' own lib.
{ inputs, ... }:
{
  flake.lib.chromiumBrowsers = import ./_chromium-browsers.nix { inherit (inputs.nixpkgs) lib; };
}
