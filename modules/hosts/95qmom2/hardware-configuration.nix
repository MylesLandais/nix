# Dell OptiPlex 7050 (Service Tag 95QMOM2)
# Intel i5-6500, 12 GB RAM, 238 GB SSD (sda, root) + 9.1 TB HDD (sdb, data)
_: {
  flake.nixosModules.qmom2Hardware =
    { config, lib, modulesPath, ... }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "ahci"
        "usbhid"
        "sd_mod"
      ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.extraModulePackages = [ ];

      # 238 GB SSD — sda3, ext4 root
      fileSystems."/" = {
        device = "/dev/disk/by-uuid/89395068-a5be-4b51-af6d-856a77ba5fa2";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/04E9-801D";
        fsType = "vfat";
        options = [ "fmask=0077" "dmask=0077" ];
      };

      # 9.1 TB HDD — sdb1, XFS, data volume (reformatted 2026-05-16)
      fileSystems."/srv/data" = {
        device = "/dev/disk/by-uuid/2f206721-500c-409c-b147-a2fdb44544b0";
        fsType = "xfs";
        options = [ "noatime" "nofail" "x-systemd.automount" ];
      };

      swapDevices = [
        { device = "/dev/disk/by-uuid/c0179c16-7ed9-4b61-afdf-ebbc7090b6d4"; }
      ];

      networking.useDHCP = lib.mkDefault true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
