{ inputs, lib, ... }:
{
  flake.nixosConfigurations.kali-vm = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
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
}
