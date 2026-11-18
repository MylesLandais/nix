{
  config,
  inputs,
  lib,
  ...
}:
{
  flake.nixosConfigurations.cerberus = config.nodeBuilders.mkHost {
    name = "cerberus";
    desktop = true;
    backupFileExtension = "hm-backup";
    modules = [
      inputs.self.modules.nixos.cerberus
      inputs.self.modules.nixos.themeData
      inputs.self.modules.nixos.desktops
      inputs.self.modules.nixos.gamehacking
      inputs.self.modules.nixos.iw4x
      inputs.self.modules.nixos.scbw
      inputs.self.modules.nixos.warcraft3
      inputs.self.modules.nixos.greeter
      inputs.self.modules.nixos.chaotic
      inputs.agenix.nixosModules.default
    ];
    users.warby = {
      homeModules = [
        inputs.self.modules.homeManager.base
        config.cerberus.home
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
          Install = lib.mkOverride 0 {
            WantedBy = [
              "graphical-session-pre.target"
              "hyprland-session.target"
            ];
          };
        };
      };
    };
  };
}
