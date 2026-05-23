{ inputs, lib, ... }:
{
  flake.nixosConfigurations.installerIso = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-base.nix"

      inputs.self.nixosModules.lacie
      inputs.self.nixosModules.wifiProfiles
      inputs.self.nixosModules.greeter
      inputs.self.nixosModules.themeData
      inputs.self.nixosModules.emulators
      inputs.self.nixosModules.pentest

      "${inputs.self}/modules/features/host-options.nix"
      "${inputs.self}/modules/features/env-packages.nix"
      "${inputs.self}/modules/features/nix-config.nix"
      "${inputs.self}/modules/features/fish-config.nix"
      "${inputs.self}/modules/features/ssh-keys.nix"

      inputs.home-manager.nixosModules.home-manager
      {
        home-manager = {
          useUserPackages = true;
          useGlobalPkgs = true;
          sharedModules = [ inputs.agenix.homeManagerModules.age ];
          users.warby = _: {
            imports = [ "${inputs.self}/modules/home.nix" ];
            home.username = lib.mkForce "warby";
            home.homeDirectory = lib.mkForce "/home/warby";
            age.identityPaths = lib.mkForce [ "/home/warby/.ssh/age" ];
          };
          users.kali = _: {
            imports = [ "${inputs.self}/modules/home.nix" ];
            home.username = lib.mkForce "kali";
            home.homeDirectory = lib.mkForce "/home/kali";
            age.identityPaths = lib.mkForce [ "/home/kali/.ssh/age" ];
          };
          extraSpecialArgs = {
            inherit inputs;
            system = "x86_64-linux";
          };
        };
      }

      (
        { config, pkgs, ... }:
        {
          image.fileName = lib.mkForce "home-office-installer.iso";
          isoImage.volumeID = lib.mkForce "HOMEOFFICE";

          # Support GRUB loopback boot via findiso= kernel parameter.
          # When the ISO is booted from a GRUB loopback menu (e.g. from lacie_isos),
          # the kernel never sees the ISO as a block device. This hook mounts the
          # isos partition, loop-mounts the ISO file, and exposes it as /dev/loop0
          # so the initrd's root-finding code can locate the squashfs by label.
          boot.initrd.availableKernelModules = [ "loop" "exfat" "iso9660" ];
          boot.initrd.extraUtilsCommands = ''
            copy_bin_and_libs ${pkgs.util-linux}/bin/losetup
          '';
          boot.initrd.postDeviceCommands = lib.mkBefore ''
            if [ -n "''${findiso}" ]; then
              mkdir -p /run/isopart
              for dev in /dev/disk/by-label/lacie_isos /dev/sd*2 /dev/nvme*p2; do
                [ -b "$dev" ] || continue
                if mount -o ro "$dev" /run/isopart 2>/dev/null; then
                  if [ -f "/run/isopart''${findiso}" ]; then
                    losetup /dev/loop0 "/run/isopart''${findiso}"
                    umount /run/isopart
                    echo "findiso: mounted ''${findiso} as /dev/loop0"
                    break
                  fi
                  umount /run/isopart
                fi
              done
            fi
          '';

          networking.hostName = lib.mkForce "home-office-installer";
          networking.wireless.enable = lib.mkForce false;
          networking.networkmanager.enable = lib.mkForce true;

          host.pentest.enable = true;
          host.emulators.enable = true;
          host.desktop = lib.mkForce "hyprland";
          host.bar = lib.mkForce "hyprpanel";
          host.greeter = lib.mkForce "sddm";
          host.wallpaper = lib.mkForce "${inputs.wallpapers.packages.x86_64-linux.default}/share/wallpapers/kanagawa-dragon/3895e.jpg";

          services.displayManager.autoLogin = {
            enable = true;
            user = "warby";
          };
          services.displayManager.defaultSession = "hyprland";

          users.users.warby = {
            hashedPassword = lib.mkForce "$y$j9T$gJkLnhuqbgOfuN6aCqCkV/$mP5AkJqviJilNvMVUTSvn5h5.IrP15ZaUelK5NARJj6";
          };

          users.users.kali = {
            isNormalUser = true;
            description = "kali (guest)";
            shell = pkgs.fish;
            hashedPassword = "$y$j9T$ptd5A6Ymz9yh6X46vvkaD/$4Qrbfo9iHSSF4w8UobrZ4/mG7eWp/6ruvTupEn6yCu2";
          };

          users.users.root.openssh.authorizedKeys.keys =
            config.users.users.warby.openssh.authorizedKeys.keys;

          services.openssh.settings.PermitRootLogin = lib.mkForce "yes";

          services.journald.storage = "persistent";

          environment.systemPackages = [
            inputs.self.packages.x86_64-linux.bootstrap-lacie
            pkgs.parted
            pkgs.gptfdisk
            pkgs.cosmic-files
            pkgs.qemu_full
            pkgs.ntfs3g
            pkgs.smartmontools
          ];

          services.getty.helpLine = lib.mkForce ''

            Home Office NixOS installer.
            Run `nix-install` to bootstrap LaCie onto an attached drive.
            (Alias of `bootstrap-lacie`. Use `--help` for options.)

          '';

          system.stateVersion = "25.11";
        }
      )
    ];
  };

  perSystem =
    { ... }:
    {
      packages.installer-iso =
        inputs.self.nixosConfigurations.installerIso.config.system.build.isoImage;
    };
}
