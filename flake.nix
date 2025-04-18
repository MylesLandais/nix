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
    pkgs = import nixpkgs {
      inherit system;
      config = {allowUnfree = true;};
      overlays = [
        hyprpanel.overlay
        sddm-sugar-candy-nix.overlays.default
      ];
    };
  in {
    nixosConfigurations."franktory" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      inherit pkgs;
      modules = with pkgs; [
        ./hosts/franktory/etc/nixos/configuration.nix
        sddm-sugar-candy-nix.nixosModules.default
        home-manager.nixosModules.home-manager
        {
          environment.systemPackages = [
            ghostty.packages.x86_64-linux.default
            zen-browser.packages.x86_64-linux.default
          ];
        }
        {
          home-manager.useUserPackages = true;
          home-manager.useGlobalPkgs = true;
          home-manager.extraSpecialArgs = {
            vars = {
              hostName = "franktory";
              isDesktop = false;
              class = "laptop";
              wallpaper = "/home/franky/wallpapers/wall-01.png";
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
    nixosConfigurations."kraken" = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      inherit pkgs;
      modules = with pkgs.overlays; [
        ./hosts/kraken/etc/nixos/configuration.nix
        sddm-sugar-candy-nix.nixosModules.default
        home-manager.nixosModules.home-manager

        {
          environment.systemPackages = [
            ghostty.packages.x86_64-linux.default
            zen-browser.packages.x86_64-linux.default
          ];
        }
        {
          home-manager.useUserPackages = true;
          home-manager.useGlobalPkgs = true;
          home-manager.extraSpecialArgs = {
            vars = {
              hostName = "kraken";
              isDesktop = true;
              class = "desktop";
              wallpaper = "/home/franky/wallpapers/sunset_kanagawa-dragon.jpg";
              mainMonitor = {
                name = "DP-4";
                width = "1920";
                height = "1080";
                refresh = "100";
              };
              secondaryMonitor = {
                name = "HDMI-A-2";
                width = "1920";
                height = "1080";
                refresh = "100";
              };
            };
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
