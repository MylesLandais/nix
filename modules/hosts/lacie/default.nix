{ inputs, lib, ... }:
{
  flake.nixosConfigurations.lacie = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      inputs.self.nixosModules.lacie
      inputs.self.nixosModules.lacieHardware
      inputs.self.nixosModules.imaging
      inputs.self.nixosModules.wifiProfiles
      inputs.self.nixosModules.greeter
      inputs.self.nixosModules.themeData
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
}
