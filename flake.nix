{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
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
        modules = with pkgs; [
          ./hosts/dell-potato/etc/nixos/configuration.nix
          home-manager.nixosModules.home-manager
          hm_user_cfg
          {
            home-manager = {
              useUserPackages = true;
              useGlobalPkgs = true;
              extraSpecialArgs = {
                vars = {
                  hostName = "dell-potato";
                };
                inherit inputs system pkgs;
              };
            };
          }
        ];
      };
};
}
