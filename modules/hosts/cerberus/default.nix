{ inputs, ... }:
let
  pkgsForVars = import inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
  vars = import "${inputs.self}/legacy/vars.nix" { pkgs = pkgsForVars; };
in
{
  flake.nixosConfigurations.cerberus = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs vars;
      # extra-types is declared-but-unused in the legacy cerberus config; stub it.
      extra-types = null;
    };
    modules = [
      (
        { ... }:
        {
          nixpkgs.overlays = [
            inputs.nur.overlays.default
            inputs.claude-code.overlays.default
            inputs.nix-vscode-extensions.overlays.default
            inputs.nix-cachyos-kernel.overlays.pinned
          ];
          networking.hostName = vars.hostName;
        }
      )
      inputs.self.nixosModules.cerberus
      inputs.chaotic.nixosModules.default
      inputs.agenix.nixosModules.default
      inputs.hermes-agent.nixosModules.default
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager = {
          useGlobalPkgs = true;
          useUserPackages = false;
          extraSpecialArgs = {
            inherit inputs vars;
            self = inputs.self;
          };
          users.warby = import "${inputs.self}/legacy/home.nix";
        };
      }
    ];
  };
}
