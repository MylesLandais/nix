{ inputs, lib, ... }:
let
  pkgsForVars = import inputs.nixpkgs {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
  vars = import "${inputs.self}/vars.nix" { pkgs = pkgsForVars; };
  mkHostLib = import ../../flake-parts/_mk-host.nix { inherit inputs lib; };
  inherit (inputs) self;
in
{
  flake.nixosConfigurations.cerberus = mkHostLib.mkHost {
    name = "cerberus";
    desktop = true;
    backupFileExtension = "hm-backup";
    modules = [
      inputs.self.nixosModules.cerberus
      inputs.self.nixosModules.themeData
      inputs.self.nixosModules.desktops
      inputs.self.nixosModules.gamehacking
      inputs.self.nixosModules.scbw
      inputs.self.nixosModules.greeter
      inputs.chaotic.nixosModules.default
      inputs.agenix.nixosModules.default
      inputs.hermes-agent.nixosModules.default
    ];
    users.warby = {
      homeModules = [
        "${self}/modules/_home.nix"
        "${self}/modules/hosts/cerberus/_home.nix"
      ];
      uid = 1000;
      ageIdentity = "/home/warby/.ssh/age";
      extraConfig = _: {
        services.gnome-keyring = {
          enable = true;
          components = [
            "pkcs11"
            "secrets"
          ];
        };
        systemd.user.services.gnome-keyring = {
          install = lib.mkOverride 0 {
            WantedBy = [
              "graphical-session-pre.target"
              "hyprland-session.target"
            ];
          };
        };
      };
    };
    extraSpecialArgs = {
      inherit vars;
      gpuType = "nvidia";
    };
  };
}
