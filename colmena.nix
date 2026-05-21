{ inputs }:
{
  meta = {
    nixpkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
    specialArgs = { inherit inputs; };
  };

  defaults = _: {
    deployment = {
      targetUser = "warby";
      buildOnTarget = false;
    };
  };

  "94tl0m2" =
    { lib, ... }:
    {
      deployment = {
        targetHost = "94tl0m2";
        tags = [
          "7050"
          "staging"
        ];
      };
      imports = [
        inputs.self.nixosModules.tl0m2
        inputs.self.nixosModules.tl0m2Hardware
        inputs.self.nixosModules.tl0m2Postgres
        inputs.self.nixosModules.tl0m2Seaweedfs
        "${inputs.self}/modules/features/nix-config.nix"
        "${inputs.self}/modules/features/fish-config.nix"
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager = {
            useUserPackages = true;
            useGlobalPkgs = true;
            users.warby =
              { pkgs, ... }:
              {
                home.username = lib.mkForce "warby";
                home.homeDirectory = lib.mkForce "/home/warby";
                home.stateVersion = "25.11";
                programs.home-manager.enable = true;
              };
            extraSpecialArgs = {
              inherit inputs;
              system = "x86_64-linux";
            };
          };
        }
      ];
    };

  "lacie" =
    { lib, ... }:
    {
      deployment = {
        targetHost = "lacie";
        tags = [
          "laptop"
          "imaging"
        ];
      };
      imports = [
        inputs.self.nixosModules.lacie
        inputs.self.nixosModules.lacieHardware
        inputs.self.nixosModules.imaging
        inputs.self.nixosModules.wifiProfiles
        inputs.self.nixosModules.greeter
        inputs.self.nixosModules.themeData
        inputs.self.nixosModules.desktops
        inputs.self.nixosModules.emulators
        inputs.self.nixosModules.pentest
        "${inputs.self}/modules/features/host-options.nix"
        "${inputs.self}/modules/features/env-packages.nix"
        "${inputs.self}/modules/features/nix-config.nix"
        "${inputs.self}/modules/features/fish-config.nix"
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager = {
            useUserPackages = true;
            useGlobalPkgs = true;
            sharedModules = [ inputs.agenix.homeManagerModules.age ];
            users.warby =
              { ... }:
              {
                imports = [ "${inputs.self}/modules/home.nix" ];
                home.username = lib.mkForce "warby";
                home.homeDirectory = lib.mkForce "/home/warby";
                age.identityPaths = lib.mkForce [ "/home/warby/.ssh/age" ];
              };
            extraSpecialArgs = {
              inherit inputs;
              system = "x86_64-linux";
            };
          };
        }
      ];
    };

  "argus" =
    { lib, ... }:
    {
      deployment = {
        targetHost = "argus";
        tags = [
          "headless"
          "gpu"
        ];
      };
      imports = [
        inputs.self.nixosModules.argus
        inputs.self.nixosModules.argusHardware
        "${inputs.self}/modules/features/nix-config.nix"
        "${inputs.self}/modules/features/fish-config.nix"
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager = {
            useUserPackages = true;
            useGlobalPkgs = true;
            users.warby =
              { pkgs, ... }:
              {
                home.username = lib.mkForce "warby";
                home.homeDirectory = lib.mkForce "/home/warby";
                home.stateVersion = "25.05";
                programs.home-manager.enable = true;
              };
            extraSpecialArgs = {
              inherit inputs;
              system = "x86_64-linux";
            };
          };
        }
      ];
    };

  "kali-vm" =
    { lib, ... }:
    {
      deployment = {
        targetHost = "kali-vm";
        tags = [
          "vm"
          "kali"
        ];
      };
      imports = [
        inputs.self.nixosModules.kaliVm
        inputs.self.nixosModules.themeData
        inputs.self.nixosModules.desktops
        "${inputs.self}/modules/features/host-options.nix"
        "${inputs.self}/modules/features/env-packages.nix"
        "${inputs.self}/modules/features/nix-config.nix"
        "${inputs.self}/modules/features/fish-config.nix"
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager = {
            useUserPackages = true;
            useGlobalPkgs = true;
            sharedModules = [ inputs.agenix.homeManagerModules.age ];
            users.kali =
              { ... }:
              {
                imports = [ "${inputs.self}/modules/home.nix" ];
                home.username = lib.mkForce "kali";
                home.homeDirectory = lib.mkForce "/home/kali";
              };
            extraSpecialArgs = {
              inherit inputs;
              system = "x86_64-linux";
            };
          };
        }
      ];
    };

  "95qmom2" =
    { lib, ... }:
    {
      deployment = {
        targetHost = "192.168.0.49";
        tags = [
          "7050"
          "storage"
          "data-core"
          "postgres"
          "seaweedfs"
        ];
      };
      imports = [
        inputs.self.nixosModules.qmom2
        inputs.self.nixosModules.qmom2Hardware
        inputs.self.nixosModules.qmom2Postgres
        inputs.self.nixosModules.qmom2Seaweedfs
        "${inputs.self}/modules/features/nix-config.nix"
        "${inputs.self}/modules/features/fish-config.nix"
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager = {
            useUserPackages = true;
            useGlobalPkgs = true;
            users.warby =
              { pkgs, ... }:
              {
                home.username = lib.mkForce "warby";
                home.homeDirectory = lib.mkForce "/home/warby";
                home.stateVersion = "25.11";
                programs.home-manager.enable = true;
                programs.git = {
                  enable = true;
                  userName = "warby";
                  userEmail = "landais.myles@gmail.com";
                };
                programs.btop = {
                  enable = true;
                  settings.theme_background = false;
                };
                home.packages = with pkgs; [
                  eza
                  zoxide
                  fzf
                  bat
                ];
              };
            extraSpecialArgs = {
              inherit inputs;
              system = "x86_64-linux";
            };
          };
        }
      ];
    };
}
