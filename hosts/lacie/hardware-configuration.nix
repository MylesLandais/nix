# Portable stub — replace with `nixos-generate-config --root /mnt` output
# after booting the target machine from the NixOS live ISO.
{ config, lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci" "ahci" "usb_storage" "sd_mod" "uas" "nvme"
  ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-label/live_nix";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/VTOYEFI";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-label/persistent_data";
    fsType = "ntfs3";
    options = [ "rw" "uid=1000" "gid=100" "umask=0022" "nofail" "x-systemd.automount" ];
  };

  swapDevices = [];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
