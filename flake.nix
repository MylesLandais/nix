{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tokyonight = {
      url = "github:mrjones2014/tokyonight.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    sddm-sugar-candy-nix = {
      url = "gitlab:Zhaith-Izaliel/sddm-sugar-candy-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprpanel = {
      url = "github:Jas-SinghFSU/HyprPanel";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghostty = {
      url = "git+ssh://git@github.com/ghostty-org/ghostty";
      inputs.nixpkgs-stable.follows = "nixpkgs";
      inputs.nixpkgs-unstable.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    home-manager,
    nixpkgs,
    sddm-sugar-candy-nix,
    zen-browser,
    ghostty,
    hyprpanel,
    nixvim,
    tokyonight,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    username = "franky";
  in {
    nixosConfigurations."kraken" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
        overlays = [
          inputs.hyprpanel.overlay
          sddm-sugar-candy-nix.overlays.default
        ];
      };
      modules = [
        ./hosts/kraken/etc/nixos/configuration.nix
        sddm-sugar-candy-nix.nixosModules.default
        {
          environment.systemPackages = [
            ghostty.packages.x86_64-linux.default
            zen-browser.packages.x86_64-linux.default
          ];
        }
        home-manager.nixosModules.home-manager
        {
          home-manager.useUserPackages = true;
          home-manager.useGlobalPkgs = true;
          home-manager.extraSpecialArgs = {
            inherit inputs;
            inherit system;
          };
          home-manager.users."${username}" = {
            imports = [
              ./home.nix
            ];
          };
        }
      ];
    };
  };
}
