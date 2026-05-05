{ inputs, ... }:
{
  flake.nixosConfigurations.installerIso = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix"
      inputs.self.nixosModules.wifiProfiles
      (
        { pkgs, lib, ... }:
        {
          isoImage = {
            isoName = lib.mkForce "home-office-installer.iso";
            volumeID = lib.mkForce "HOMEOFFICE";
          };

          # Minimal ISO ships wpa_supplicant by default — disable in favour of NM.
          networking = {
            wireless.enable = lib.mkForce false;
            networkmanager.enable = true;
            hostName = lib.mkForce "installer";
          };

          services.openssh = {
            enable = true;
            settings = {
              PermitRootLogin = "yes";
              PasswordAuthentication = false;
            };
          };

          # Drop cerberus's SSH key here when ready for headless installs.
          # users.users.root.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAA..." ];

          environment.systemPackages = with pkgs; [
            inputs.self.packages.x86_64-linux.bootstrap-lacie
            git
            parted
            gptfdisk
            vim
            tmux
            htop
          ];

          services.getty.helpLine = lib.mkForce ''

            Home Office NixOS installer.
            Run `nix-install` to bootstrap LaCie onto an attached drive.
            (Alias of `bootstrap-lacie`. Use `--help` for options.)

          '';

          users.users.nixos.shell = pkgs.bash;
          users.users.root.shell = pkgs.bash;

          system.stateVersion = "25.11";
        }
      )
    ];
  };

  perSystem =
    { system, ... }:
    {
      packages.installer-iso =
        inputs.self.nixosConfigurations.installerIso.config.system.build.isoImage;
    };
}
