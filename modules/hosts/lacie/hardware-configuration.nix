_: {
  # Stub — regenerated during Phase 4 bootstrap via:
  #   nixos-generate-config --root /mnt --no-filesystems
  # bootstrap-lacie copies the generated file over this one.
  flake.nixosModules.lacieHardware =
    {
      config,
      lib,
      modulesPath,
      ...
    }:
    {
      imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

      boot = {
        initrd = {
          availableKernelModules = [
            "xhci_pci"
            "ahci"
            "usb_storage"
            "sd_mod"
            "uas"
            "nvme"
          ];
          kernelModules = [ ];
        };
        kernelModules = [ ];
        extraModulePackages = [ ];
      };

      # Filesystems live in nixosModules.imaging via host.imaging.enable.

      swapDevices = [ ];
      networking.useDHCP = lib.mkDefault true;
      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware = {
        cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      };
    };
}
