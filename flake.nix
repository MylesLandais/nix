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
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";  # Core packages
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable"; # Additional packages
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
      system = "x86_64-linux";
      username = "warby";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
      };
      hm_user_cfg = {
        home-manager.users."${username}" = {
          imports = [
            ./home.nix
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
