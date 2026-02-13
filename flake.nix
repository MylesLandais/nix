{
  description = "Cerberus NixOS Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix.url = "github:danth/stylix";
    tokyonight.url = "github:mrjones2014/tokyonight.nix";
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
    };
    nur.url = "github:nix-community/NUR";
    thorium.url = "github:Rishabh5321/thorium_flake";
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    cursor-flake = {
      url = "github:omarcresp/cursor-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    claude-code.url = "github:sadjow/claude-code-nix";
    antigravity.url = "github:jacopone/antigravity-nix";
    agenix.url = "github:ryantm/agenix";
    zed.url = "github:zed-industries/zed";
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    opencode = {
      url = "github:anomalyco/opencode";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      chaotic,
      nixpkgs,
      home-manager,
      nur,
      thorium,
      zen-browser,
      cursor-flake,
      antigravity,
      agenix,
      zed,
      opencode,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
        overlays = [
          inputs.nix-vscode-extensions.overlays.default
          inputs.claude-code.overlays.default
          inputs.antigravity.overlays.default
        ];
      };
      vars = import ./vars.nix { inherit pkgs; };
    in
    {
      nixosConfigurations.cerberus = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs vars; };
        modules = [
          ({ config, pkgs, ... }: {
            nixpkgs.overlays = [
              nur.overlays.default
              inputs.nix-cachyos-kernel.overlays.pinned
            ];
          })
          ./hosts/cerberus/configuration.nix
          chaotic.nixosModules.default
          inputs.agenix.nixosModules.default
          ./modules/gnome-keyring.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = false;
              extraSpecialArgs = { inherit inputs vars; };
              users.warby = import ./home.nix;
            };
            networking.hostName = vars.hostName;
          }
        ];
      };
    };
}
