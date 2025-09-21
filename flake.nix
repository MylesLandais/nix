{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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
    nixvim = {
      url = "github:nix-community/nixvim";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    sddm-sugar-candy-nix = {
      url = "gitlab:Zhaith-Izaliel/sddm-sugar-candy-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    ghostty = {
      url = "git+ssh://git@github.com/ghostty-org/ghostty";
    };
    wallpapers = {
      url = "github:FKouhai/Kanagawa-wallpapers";
    };
  };

  outputs =
    {
      self,
      home-manager,
      nixpkgs,
      sddm-sugar-candy-nix,
      zen-browser,
      ghostty,
      stylix,
      wallpapers,
      nixvim,
      tokyonight,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      username = "franky";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
        overlays = [
          sddm-sugar-candy-nix.overlays.default
        ];
      };
      env_pkgs = {
        environment.systemPackages = [
          ghostty.packages.x86_64-linux.default
          zen-browser.packages.x86_64-linux.default
          wallpapers.packages.x86_64-linux.default
        ];
      };
      hm_user_cfg = {
        home-manager.users."${username}" = {
          imports = [
            ./home.nix
          ];
        };
      };
    in
    {
      nixosConfigurations."franktory" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit pkgs;
        modules = with pkgs; [
          ./hosts/franktory/etc/nixos/configuration.nix
          sddm-sugar-candy-nix.nixosModules.default
          home-manager.nixosModules.home-manager
          env_pkgs
          hm_user_cfg
          {
            home-manager = {
              useUserPackages = true;
              useGlobalPkgs = true;
              extraSpecialArgs = {
                vars = {
                  hostName = "franktory";
                  isDesktop = false;
                  class = "laptop";
                  wallpaper = "${wallpapers}/kanagawa-dragon/sciel.jpg";
                  mainMonitor = {
                    name = "eDP-1";
                    width = "1920";
                    height = "1080";
                    refresh = "60";
                  };
                  secondaryMonitor = {
                    name = "HDMI-A-1";
                    width = "1920";
                    height = "1080";
                    refresh = "60";
                  };
                };
                inherit inputs system;
              };
            };
          }
        ];
      };

      nixosConfigurations."kraken" = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        inherit pkgs;

        modules = with pkgs.overlays; [
          ./hosts/kraken/etc/nixos/configuration.nix
          sddm-sugar-candy-nix.nixosModules.default
          home-manager.nixosModules.home-manager
          env_pkgs
          hm_user_cfg

          {
            home-manager = {
              useUserPackages = true;
              useGlobalPkgs = true;
              extraSpecialArgs = {
                vars = {
                  hostName = "kraken";
                  isDesktop = true;
                  class = "desktop";
                  wallpaper = "${wallpapers}/kanagawa-dragon/sciel.jpg";
                  mainMonitor = {
                    name = "DP-4";
                    width = "2560";
                    height = "1440";
                    refresh = "180";
                  };
                  secondaryMonitor = {
                    name = "HDMI-A-2";
                    width = "2560";
                    height = "1440";
                    refresh = "180";
                  };
                };
                inherit inputs system;
              };
            };
          }
        ];
      };
    };
}
