# Chaotic Overlay Configuration Issue

## Problem Description

The chaotic overlay in `flake.nix` is attempting to reference the `system` variable, which is not defined in the scope where the overlay is created. This causes an "undefined variable 'system'" error when Nix attempts to evaluate the flake.

The issue occurs because the `chaotic-overlay` is defined in the first `let` block, but `system` is only defined in the subsequent `let` block. In Nix, variables are only accessible within their own `let` block or after their definition.

## Current flake.nix Configuration

```nix
# ============================================================================
# NixOS Flake Configuration - Agent Sandbox Infrastructure
# ============================================================================
#
# This flake defines the complete NixOS configuration for the Agent Sandbox,
# a modular development environment optimized for AI agents and comprehensive
# software development workflows.
#
# INPUTS:
# =======
# - nixpkgs: Core Nix package repository (unstable channel)
# - chaotic: Additional packages from Chaotic-AUR (cutting-edge software)
# - home-manager: User environment management
# - agenix: Secrets management with age encryption
# - tokyonight: Color scheme for terminals and editors
# - stylix: System-wide theming framework
#
# ARCHITECTURE:
# =============
# - Modular design: Separate concerns into logical modules
# - Host-specific configs: dell-potato (gaming workstation)
# - User management: Home Manager for declarative user environments
# - Secrets: Encrypted with agenix, decrypted at runtime
#
# DEPLOYMENT:
# ===========
# - Build: nix build .#nixosConfigurations.dell-potato.config.system.build.toplevel
# - Switch: sudo nixos-rebuild switch --flake .
# - Update: nix flake update
#
# MAINTENANCE:
# ============
# - Keep inputs updated regularly
# - Test builds before deploying to production
# - Use flake.lock for reproducible builds
#
# ============================================================================

{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/master";  # Core packages
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable"; # Additional packages with CachyOS kernel
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";  # Pin to same nixpkgs
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";  # Pin to same nixpkgs
    };
    tokyonight = {
      url = "github:mrjones2014/tokyonight.nix";  # Terminal themes
    };
    stylix = {
      url = "github:danth/stylix";  # System theming
    };
  };

  outputs =
    {
      self,
      chaotic,
      home-manager,
      nixpkgs,
      agenix,
      stylix,
      tokyonight,
      ...
    }@inputs:
    let
      # Add Chaotic Nyx overlay for CachyOS kernel access
      chaotic-overlay = final: prev: {
        linuxPackages_cachyos = chaotic.packages.${system}.linuxPackages_cachyos;
      };
    in
    let
      system = "x86_64-linux";
      username = "warby";
      overlay = final: prev: {
        libretro-thepowdertoy = prev.libretro-thepowdertoy.overrideAttrs (oldAttrs: {
          cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
            "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
            "-DCMAKE_POLICY_DEFAULT_CMP0025=NEW"
          ];
        });
      };
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [ "mbedtls-2.28.10" ];
        };
        overlays = [ overlay chaotic-overlay ];
      };
      hm_user_cfg = {
        home-manager.users."${username}" = {
          imports = [
            ./home.nix
            ./hosts/dell-potato/etc/nixos/home-manager/home.nix
          ];
          home.stateVersion = "24.11";
        };
      };
    in
    {
      nixosConfigurations."dell-potato" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit pkgs;
        specialArgs = {
          inherit inputs;
        };
        modules = [
          ./hosts/dell-potato/etc/nixos/configuration.nix
          ./modules/gaming.nix
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          hm_user_cfg
          {
            home-manager = {
              useUserPackages = true;
              useGlobalPkgs = true;
              backupFileExtension = "backup";
              extraSpecialArgs = {
                vars = {
                  hostName = "dell-potato";
                  username = "warby";
                };
                inherit inputs system pkgs;
              };
            };
          }
        ];
      };
    };
}
```

## Error Message

```
error: undefined variable 'system'

       at /home/warby/Workspace/Nixos/flake.nix:72:52:

           71 |       # Add Chaotic Nyx overlay for CachyOS kernel access
           72 |       chaotic-overlay = final: prev: {
           73 |         linuxPackages_cachyos = chaotic.packages.${system}.linuxPackages_cachyos;
             |                                                    ^
           74 |       };
```

## Root Cause

The `system` variable is defined in the second `let` block (line 77), but the `chaotic-overlay` is defined in the first `let` block (lines 71-74). In Nix, variables defined in a `let` block are only accessible within that block and subsequent expressions, but not in nested `let` blocks that come before their definition.

## Potential Solutions

1. Move the `system` definition before the `chaotic-overlay` definition.
2. Define `system` in the same `let` block as `chaotic-overlay`.
3. Pass `system` as a parameter to the overlay function.
4. Restructure the `let` blocks to ensure proper scoping.