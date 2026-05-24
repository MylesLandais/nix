{ inputs, lib, ... }:
let
  pkgsForVars = import inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
  vars = import "${inputs.self}/vars.nix" { pkgs = pkgsForVars; };
in
{
  flake.nixosConfigurations.cerberus = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      extra-types = null;
    };
    modules = [
      inputs.self.nixosModules.cerberus
      inputs.self.nixosModules.themeData
      inputs.self.nixosModules.desktops
      "${inputs.self}/modules/features/host-options.nix"
      "${inputs.self}/modules/features/env-packages.nix"
      "${inputs.self}/modules/features/nix-config.nix"
      "${inputs.self}/modules/features/fish-config.nix"
      inputs.chaotic.nixosModules.default
      inputs.agenix.nixosModules.default
      inputs.hermes-agent.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager = {
          useUserPackages = true;
          useGlobalPkgs = true;
          backupFileExtension = "hm-backup";
          sharedModules = [ inputs.agenix.homeManagerModules.age ];
          users.warby =
            { ... }:
            {
              imports = [
                "${inputs.self}/modules/home.nix"
                "${inputs.self}/hosts/cerberus/home.nix"
              ];
              home.username = lib.mkForce "warby";
              home.homeDirectory = lib.mkForce "/home/warby";
              age.identityPaths = lib.mkForce [ "/home/warby/.ssh/age" ];
              # gnome-keyring user session: pkcs11 + secrets only.
              # `ssh` is intentionally excluded so bitwarden-ssh-agent stays
              # the sole owner of SSH_AUTH_SOCK (see modules/home.nix:52).
              services.gnome-keyring = {
                enable = true;
                components = [ "pkcs11" "secrets" ];
              };
            };
          extraSpecialArgs = {
            inherit inputs vars;
            system = "x86_64-linux";
            self = inputs.self;
          };
        };
      }
    ];
  };
}
