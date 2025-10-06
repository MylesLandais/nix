{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tokyonight = {
      url = "github:mrjones2014/tokyonight.nix";
    };
    stylix = {
      url = "github:danth/stylix";
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
