# Dell OptiPlex 7020 (Service Tag 8ZZWD22)
# Haswell (4th-gen Intel), 2x Quadro K2200, SSD root, 4TB data HDD
#
# NOTE: This is a scaffold. Run `nixos-generate-config --root /mnt` from the
# live ISO after partitioning to get the real disk UUIDs, then paste them in.
_: {
  flake.nixosModules.argusHardware =
    { config, lib, modulesPath, ... }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      # USB/SATA boot support plus KVM for any future VMs.
      boot.initrd.availableKernelModules = [
        "xhci_pci"     # USB 3.0
        "ahci"         # SATA
        "usb_storage"  # USB disks
        "sd_mod"       # SD cards
        "uas"          # USB-attached SCSI
        "nvme"         # in case an NVMe adapter is ever added
      ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-intel" ];
      boot.extraModulePackages = [ ];

      # ---------------------------------------------------------------------------
      # TODO: Replace with actual UUIDs from `nixos-generate-config --root /mnt`
      # ---------------------------------------------------------------------------
      fileSystems."/" = {
        device = "/dev/disk/by-uuid/SSD_ROOT_UUID";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/EFI_UUID";
        fsType = "vfat";
        options = [ "fmask=0077" "dmask=0077" ];
      };

      # 4TB bulk storage — ext4 is fine for a single-disk SeaweedFS backend.
      # If you prefer btrfs or zfs, change fsType and options accordingly.
      fileSystems."/srv/data" = {
        device = "/dev/disk/by-uuid/DATA_HDD_UUID";
        fsType = "ext4";
        options = [ "noatime" "nofail" "x-systemd.automount" ];
      };

      swapDevices = [ ];

      networking.useDHCP = lib.mkDefault true;

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
