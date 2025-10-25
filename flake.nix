{
  description = "Cerberus NixOS Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    stylix.url = "github:danth/stylix";
    tokyonight.url = "github:mrjones2014/tokyonight.nix";
    nix-vscode-extensions = {
      url = "github:nix-community/nix-vscode-extensions";
    };
    # Add other inputs (e.g., goose-ai) as needed
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let vars = import ./vars.nix; in {
    nixosConfigurations.cerberus = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./hosts/cerberus/configuration.nix
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
          nixpkgs.overlays = [ inputs.nix-vscode-extensions.overlays.default ];
          nixpkgs.config.allowUnfreePredicate = pkg: pkg.pname == "nvidia-x11";
        }
      ];
    };
  };
}
