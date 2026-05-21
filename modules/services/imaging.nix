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
    in
    {
      config = lib.mkIf cfg.enable (lib.mkMerge [
        {
          boot.loader.systemd-boot = {
            enable = lib.mkDefault true;
            editor = false;
          };
          boot.loader.efi = {
            canTouchEfiVariables = false;
            efiSysMountPoint = "/boot";
          };
          # systemd-boot with canTouchEfiVariables=false relies on the EFI
          # removable-media fallback path (\EFI\BOOT\BOOTX64.EFI) — no NVRAM writes.
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

          fileSystems = {
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
            "/mnt/data" = {
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
          };
        }

        (lib.mkIf (!isAmnesic) {
          fileSystems = {
            "/" = {
              device = "/dev/disk/by-label/${cfg.homeLabel}";
              fsType = "ext4";
              options = [ "noatime" ];
            };
            "/boot" = {
              device = "/dev/disk/by-label/VTOYEFI";
              fsType = "vfat";
              options = [ "umask=0077" ];
            };
          };
        })

        (lib.mkIf isAmnesic {
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
              device = "/dev/disk/by-label/VTOYEFI";
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
