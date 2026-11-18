#!/usr/bin/env bash
# Exercise both published constructors with foreign NixOS and Home Manager modules.
set -euo pipefail
nix eval --json --no-write-lock-file ".#lib" --apply '
  api:
  let
    common = {
      baseline = false;
      users.guest.homeModules = [
        ({ inputs, system, homeMarker, ... }: {
          home.stateVersion = "25.05";
          home.sessionVariables = {
            inherit homeMarker system;
            pin = inputs.nixpkgs.rev;
          };
        })
      ];
      extraSpecialArgs.homeMarker = "external-home";
      modules = [];
    };
    host = api.mkHost (common // {
      specialArgs.systemMarker = "external-host";
      modules = [ ({ inputs, systemMarker, ... }: {
        networking.hostName = systemMarker;
        environment.variables.TEST_PIN = inputs.nixpkgs.rev;
      }) ];
    });
    cfg = host.config;
    hm = cfg.home-manager.users.guest.home.sessionVariables;
    # A standalone caller can select the target system for its home modules.
    foreign = api.mkModules (common // { system = "aarch64-linux"; });
    lastModule = builtins.elemAt foreign (builtins.length foreign - 1);
    args = lastModule.home-manager.extraSpecialArgs;
  in
  assert (builtins.functionArgs api.mkHost).specialArgs;
  assert (builtins.functionArgs api.mkModules).extraSpecialArgs;
  assert cfg.networking.hostName == "external-host";
  assert hm.homeMarker == "external-home" && hm.system == "x86_64-linux";
  assert hm.pin == cfg.environment.variables.TEST_PIN;
  assert args.system == "aarch64-linux" && args.homeMarker == hm.homeMarker;
  assert args.inputs.nixpkgs.rev == hm.pin;
  true
'

locked=$(jq -er '.nodes[.nodes[.root].inputs.nixpkgs].locked.rev' flake.lock)
test "$(nix eval --raw --no-write-lock-file .#colmena.meta.specialArgs.inputs.nixpkgs.rev)" = "$locked"
