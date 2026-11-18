# flake.lib: plain functions shared by NixOS and home-manager modules.
# Built from inputs.nixpkgs.lib, the same lib the hosts evaluate with, rather
# than flake-parts' own lib.
{
  config,
  inputs,
  lib,
  ...
}:
{
  options.flake.lib = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.raw;
    description = "Library functions and values exported by this flake.";
  };

  options.dell7050 = lib.mkOption {
    # Callers can invoke the returned NixOS modules as functions.
    type = lib.types.attrsOf (lib.types.addCheck lib.types.raw lib.isFunction);
    description = "Parameterized NixOS roles used by the Dell 7050 hosts.";
  };

  config.flake.lib = {
    chromiumBrowsers = import ./_chromium-browsers.nix { inherit (inputs.nixpkgs) lib; };
    inherit (config) dell7050;
  };
}
