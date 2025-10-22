{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/master"; # Core packages
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable"; # Additional packages with CachyOS kernel
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs"; # Pin to same nixpkgs
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs"; # Pin to same nixpkgs
    };
    tokyonight = {
      url = "github:mrjones2014/tokyonight.nix"; # Terminal themes
    };
    stylix = {
      url = "github:danth/stylix"; # System theming
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
    in
    let
      username = "warby";
      overlay = final: prev: {
        libretro-thepowdertoy = prev.libretro-thepowdertoy.overrideAttrs (oldAttrs: {
          cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
            "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
            "-DCMAKE_POLICY_DEFAULT_CMP0025=NEW"
          ];
        });
        snes9x-gtk = prev.snes9x-gtk.overrideAttrs (oldAttrs: {
          cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
            "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
          ];
        });
      };
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [ "mbedtls-2.28.10" ];
        };
        overlays = [
          overlay
        ];
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
          chaotic.nixosModules.default
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
