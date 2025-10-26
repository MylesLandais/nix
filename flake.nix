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
  };

  outputs =
    {
      self,
      chaotic,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
        overlays = [ inputs.nix-vscode-extensions.overlays.default ];
      };
      vars = import ./vars.nix { inherit pkgs; };
    in
    {
      packages.${system} = {
        sillytavern = import ./sillytavern.nix { inherit (pkgs) lib buildNpmPackage fetchFromGitHub nodejs git; };
      };

      nixosConfigurations.cerberus = nixpkgs.lib.nixosSystem {
        inherit system pkgs;
        specialArgs = { inherit inputs vars; };
        modules = with pkgs; [
          ./hosts/cerberus/configuration.nix
          chaotic.nixosModules.default
          ./modules/gnome-keyring.nix
          ./modules/sillytavern.nix
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
