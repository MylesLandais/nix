{
  description = "Cerberus NixOS Flake";

  nixConfig = {
    extra-substituters = [
      "https://nix-community.cachix.org/"
      "https://chaotic-nyx.cachix.org/"
      "https://attic.xuyh0120.win/lantian"
      "https://cache.nixos.org/"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8"
      "lantian:EeAUQ+W+6r7EtwnmYjeVwx5kOGEBpjlBfPlzGlTNvHc="
    ];
  };

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
    nixified-ai.url = "github:nixified-ai/flake";
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
          # inputs.nixified-ai.nixosModules.comfyui
          # TODO Broken Input // pending removal
          ./modules/gnome-keyring.nix
          #./modules/sillytavern.nix
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
