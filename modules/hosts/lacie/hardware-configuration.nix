# Portable stub — replace with `nixos-generate-config --root /mnt` output
# after booting the target machine from the NixOS live ISO (see bootstrap-lacie).
# FileSystems for imaging mode are owned by nixosModules.imaging; this module
# supplies kernel modules and hostPlatform only once imaging is enabled.
_: {
  flake.modules.nixos.lacieHardware =
    {
      lib,
      modulesPath,
      ...
    }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "ahci"
        "usb_storage"
        "sd_mod"
        "uas"
        "nvme"
      ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ ];
      boot.extraModulePackages = [ ];

      # When imaging is not active (e.g. early bootstrap), provide label-based
      # mounts matching the LaCie layout. imaging.nix overrides these with
      # mkForce when host.imaging.enable is set.
      fileSystems."/" = lib.mkDefault {
        device = "/dev/disk/by-label/live_nix";
        fsType = "ext4";
        options = [ "noatime" ];
      };

      fileSystems."/boot" = lib.mkDefault {
        device = "/dev/disk/by-label/LACIE_EFI";
        fsType = "vfat";
        options = [ "umask=0077" ];
      };

      fileSystems."/mnt/isos" = lib.mkDefault {
        device = "/dev/disk/by-label/lacie_isos";
        fsType = "exfat";
        options = [
          "rw"
          "uid=1000"
          "gid=100"
          "umask=0022"
          "nofail"
          "x-systemd.automount"
        ];
      };

      fileSystems."/mnt/data" = lib.mkDefault {
        device = "/dev/disk/by-label/persistent_data";
        fsType = "ntfs3";
        options = [
          "rw"
          "uid=1000"
          "gid=100"
          "umask=0022"
          "nofail"
          "x-systemd.automount"
        ];
      };

      swapDevices = lib.mkDefault [ ];

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
