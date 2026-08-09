# QEMU/virtio stub for kali-vm. Enough for nixosConfigurations.kali-vm to
# evaluate and for `nixos-rebuild build-vm`.
_: {
  flake.nixosModules.kaliVmHardware =
    { lib, modulesPath, ... }:
    {
      imports = [
        (modulesPath + "/profiles/qemu-guest.nix")
      ];

      boot.initrd.availableKernelModules = [
        "virtio_pci"
        "virtio_blk"
        "virtio_scsi"
        "virtio_net"
        "ahci"
        "sd_mod"
      ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ ];
      boot.extraModulePackages = [ ];

      fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-label/ESP";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };

      swapDevices = [ ];

      boot.loader = {
        systemd-boot.enable = true;
        efi.canTouchEfiVariables = true;
      };

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    };
}
