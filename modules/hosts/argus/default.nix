{ inputs, lib, ... }:
{
  flake.nixosConfigurations.argus = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      inputs.self.nixosModules.argus
      inputs.self.nixosModules.argusHardware
      # Server-only — no desktop/greeter/theme/home modules.
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
              programs.git = {
                enable = true;
                userName = "warby";
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
