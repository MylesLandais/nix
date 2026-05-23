_: {
  flake.nixosModules.imaging =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.host.imaging;
      isAmnesic = cfg.mode == "amnesic";
      isGrub = cfg.mode == "grub";
      isVentoy = cfg.mode == "ventoy";
    in
    {
      config = lib.mkIf cfg.enable (lib.mkMerge [
        {
          boot.loader.efi = {
            canTouchEfiVariables = false;
            efiSysMountPoint = "/boot";
          };
          # No NVRAM writes — relies on EFI removable-media fallback (\EFI\BOOT\BOOTX64.EFI).
          boot.kernelParams = [
            "rootwait"
            "quiet"
          ];
          boot.supportedFilesystems = [
            "ntfs"
            "exfat"
          ];

          environment.systemPackages = with pkgs; [
            ntfs3g
            exfatprogs
            parted
            gptfdisk
          ];

          fileSystems."/mnt/data" = {
            device = "/dev/disk/by-label/${cfg.shareLabel}";
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
        }

        # grub mode: native GRUB ESP (LACIE_EFI) + exFAT ISO partition
        (lib.mkIf isGrub {
          boot.loader.grub = {
            enable = lib.mkDefault true;
            device = lib.mkDefault "nodev";
            efiSupport = lib.mkDefault true;
            efiInstallAsRemovable = lib.mkDefault true;
            copyKernels = lib.mkDefault false;
          };
          boot.loader.systemd-boot.enable = false;

          fileSystems = {
            "/" = {
              device = "/dev/disk/by-label/${cfg.homeLabel}";
              fsType = "ext4";
              options = [ "noatime" ];
            };
            "/boot" = {
              device = "/dev/disk/by-label/${cfg.espLabel}";
              fsType = "vfat";
              options = [ "umask=0077" ];
            };
            "/mnt/isos" = {
              device = "/dev/disk/by-label/${cfg.isosLabel}";
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
          };
        })

        # ventoy mode: legacy Ventoy VTOYEFI layout + exFAT images partition
        (lib.mkIf (isVentoy && !isAmnesic) {
          boot.loader.systemd-boot = {
            enable = lib.mkDefault true;
            editor = false;
          };

          fileSystems = {
            "/" = {
              device = "/dev/disk/by-label/${cfg.homeLabel}";
              fsType = "ext4";
              options = [ "noatime" ];
            };
            "/boot" = {
              device = "/dev/disk/by-label/${cfg.espLabel}";
              fsType = "vfat";
              options = [ "umask=0077" ];
            };
            "/mnt/images" = {
              device = "/dev/disk/by-label/${cfg.imagesLabel}";
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
          };
        })

        (lib.mkIf isAmnesic {
          boot.loader.systemd-boot = {
            enable = lib.mkDefault true;
            editor = false;
          };

          fileSystems = {
            "/" = {
              device = "none";
              fsType = "tmpfs";
              options = [
                "defaults"
                "size=4G"
                "mode=755"
              ];
            };
            "/boot" = {
              device = "/dev/disk/by-label/${cfg.espLabel}";
              fsType = "vfat";
              options = [ "umask=0077" ];
            };
            "/persist" = {
              device =
                if cfg.homeLuks then "/dev/mapper/persist" else "/dev/disk/by-label/${cfg.homeLabel}";
              fsType = "ext4";
              options = [ "noatime" ];
              neededForBoot = true;
            };
          };

          boot.initrd.luks.devices = lib.mkIf cfg.homeLuks {
            persist = {
              device = "/dev/disk/by-label/${cfg.homeLabel}";
              allowDiscards = true;
              # Passphrase prompt at boot — keyfile-on-live_nix would defeat encryption-at-rest.
            };
          };
        })
      ]);
    };
}
