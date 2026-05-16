{ inputs, lib, ... }:
{
  flake.nixosConfigurations."95qmom2" = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      inputs.self.nixosModules.qmom2
      inputs.self.nixosModules.qmom2Hardware
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

  flake.deploy.nodes."95qmom2" = {
    hostname = "192.168.0.49";
    profiles.system = {
      user = "root";
      sshUser = "warby";
      path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos inputs.self.nixosConfigurations."95qmom2";
    };
    sshOpts = [ "-i" "/home/warby/.ssh/id_ed25519" ];
  };
}
