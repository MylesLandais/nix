# flake.lib: plain functions shared by NixOS and home-manager modules.
# Built from inputs.nixpkgs.lib, the same lib the hosts evaluate with, rather
# than flake-parts' own lib.
{ inputs, lib, ... }:
{
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    description = "Library functions and values exported by this flake.";
  };

  config.flake.lib = {
    chromiumBrowsers = import ./_chromium-browsers.nix { inherit (inputs.nixpkgs) lib; };
  };
}
