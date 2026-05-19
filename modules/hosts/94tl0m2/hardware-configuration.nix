# Dell OptiPlex 7050 (Service Tag 94TL0M2)
# Intel CPU, 16 GB RAM, 1 TB Samsung PM981 NVMe (nvme0n1, boot/swap/root) + 9.1 TB WD HDD (sda, /srv/data)
_: {
  flake.nixosModules.tl0m2Hardware =
    { config, lib, modulesPath, ... }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "uas"
        "sd_mod"
        "sr_mod"
      ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.extraModulePackages = [ ];

      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-label/BOOT";
        fsType = "vfat";
        options = [ "fmask=0077" "dmask=0077" ];
      };

      fileSystems."/srv/data" = {
        device = "/dev/disk/by-label/data";
        fsType = "xfs";
        options = [ "noatime" "nofail" "x-systemd.automount" ];
      };

      swapDevices = [
        { device = "/dev/disk/by-label/swap"; }
      ];

      networking.useDHCP = lib.mkDefault true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
