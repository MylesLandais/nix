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
