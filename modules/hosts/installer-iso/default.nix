{ inputs, lib, ... }:
{
  # home-office-installer: minimal recovery/install shim.
  #
  # Goal: a ~1–4 GB console-only ISO that boots fast, brings up sshd with our
  # cluster authorized_keys, and ships just enough tooling to drive a recovery
  # session (parted, gptfdisk, ntfs3g, e2fsprogs, dosfstools, smartmontools,
  # nixos-enter, nixos-install) plus the bootstrap-lacie binary.
  #
  # Anything richer (hyprland desktop, pentest toolkit, emulators, full
  # qemu_full, home-manager profiles, ...) is layered on lacie post-install,
  # NOT in the live shim. See modules/hosts/lacie/configuration.nix.
  flake.nixosConfigurations.installerIso = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      "${inputs.nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"

      "${inputs.self}/modules/features/ssh-keys.nix"

      (
        { config, pkgs, ... }:
        let
          flakeRev =
            inputs.self.rev or inputs.self.dirtyRev or "unknown";
          flakeShortRev =
            inputs.self.shortRev or
              (if (inputs.self ? dirtyShortRev) then inputs.self.dirtyShortRev else "dirty");
          nixpkgsRev = inputs.nixpkgs.rev or inputs.nixpkgs.shortRev or "unknown";
          authorizedKeys = config.users.users.warby.openssh.authorizedKeys.keys;
          buildInfo = pkgs.runCommand "iso-build-info"
            {
              nativeBuildInputs = [ pkgs.openssh ];
              keys = lib.concatStringsSep "\n" authorizedKeys + "\n";
              passAsFile = [ "keys" ];
            }
            ''
              {
                echo "home-office-installer build info (shim)"
                echo "========================================"
                echo "flake-rev:       ${flakeRev}"
                echo "flake-shortRev:  ${flakeShortRev}"
                echo "nixpkgs-rev:     ${nixpkgsRev}"
                echo "system:          x86_64-linux"
                echo "edition:         minimal-shim"
                echo
                echo "authorized_keys fingerprints (warby == root):"
                ssh-keygen -lf "$keysPath" || true
                echo
                echo "verify from cerberus:"
                echo "  ssh warby@<ip> cat /etc/iso-build-info"
              } > $out
            '';
        in
        {
          # `installation-cd-minimal.nix` forces isoImage.edition = "minimal"
          # which in turn drives isoImage.isoName / image.fileName. Override
          # isoName directly so the file is always written as
          # home-office-installer.iso, matching lacie's GRUB iso_path entry.
          isoImage.isoName = lib.mkForce "home-office-installer.iso";
          image.fileName = lib.mkForce "home-office-installer.iso";
          isoImage.volumeID = lib.mkForce "HOMEOFFICE";

          # mksquashfs defaults to xz which pegs all CPU cores for many
          # minutes and runs the laptop hot. zstd -L 6 is ~5-10x faster,
          # ~10-15% larger, and cool enough to iterate on. Iteration speed
          # beats one-shot size for a shim that fits in 2 GB either way.
          isoImage.squashfsCompression = lib.mkForce "zstd -Xcompression-level 6";

          # GRUB loopback boot path: legacy (non-systemd) initrd. Upstream
          # stage-1-init.sh handles findiso= natively (nixpkgs
          # nixos/modules/system/boot/stage-1-init.sh:247,513-533): it
          # blkid-scans every block device, finds the ISO file, symlinks
          # it to /dev/root, and root=fstab from the ISO mounts /iso and
          # the squashfs from there. systemd initrd does NOT support this
          # path — its sysroot-iso.mount unit insists on a pre-existing
          # /dev/disk/by-label/${volumeID}, which doesn't exist when the
          # ISO is only present as a file on another partition.
          boot.initrd.systemd.enable = lib.mkForce false;
          boot.initrd.kernelModules = [
            "loop"
            "exfat"
            "iso9660"
            "vfat"
          ];

          networking.hostName = lib.mkForce "home-office-installer";
          networking.wireless.enable = lib.mkForce false;
          # networkd is enough for the shim — networkmanager pulls in
          # ModemManager + dbus glue we don't want in a recovery image.
          networking.useNetworkd = true;
          networking.useDHCP = lib.mkForce false;
          systemd.network.networks."10-wired" = {
            matchConfig.Type = "ether";
            networkConfig = {
              DHCP = "yes";
              MulticastDNS = true;
              IPv6AcceptRA = true;
            };
            dhcpV4Config.UseDNS = true;
          };

          # Tailscale for out-of-LAN access when the wired DHCP path is not
          # reachable (e.g. customer's office). Adds ~30MB but is decisive
          # for remote recovery.
          services.tailscale.enable = true;

          services.openssh = {
            enable = true;
            settings = {
              UseDns = false;
              PasswordAuthentication = false;
              KbdInteractiveAuthentication = false;
              PermitRootLogin = lib.mkForce "prohibit-password";
            };
          };

          # warby user — primary recovery driver. Empty hashedPassword =
          # passwordless console login (single-user portable USB threat
          # model). SSH still requires keys.
          users.users.warby = {
            isNormalUser = true;
            description = "warby";
            extraGroups = [
              "wheel"
              "networkmanager"
            ];
            hashedPassword = "";
            shell = pkgs.bash;
          };

          users.users.root.openssh.authorizedKeys.keys =
            config.users.users.warby.openssh.authorizedKeys.keys;

          # wheel without password — the live image is throwaway; pairing
          # this with key-only sshd keeps remote sessions safe.
          security.sudo.wheelNeedsPassword = false;

          services.journald.storage = "persistent";

          environment.etc."iso-build-info".source = buildInfo;

          environment.systemPackages = with pkgs; [
            inputs.self.packages.x86_64-linux.bootstrap-lacie

            parted
            gptfdisk
            ntfs3g
            dosfstools
            e2fsprogs
            exfatprogs
            util-linux
            smartmontools

            git
            vim
            tmux
            htop
            ripgrep
            fd
            curl
            wget
            mosh

            tailscale
            cifs-utils
            wireguard-tools
          ];

          services.getty.helpLine = lib.mkForce ''

            Home Office NixOS installer (shim rev ${flakeShortRev}).
            Run `nix-install` to bootstrap LaCie onto an attached drive.
            Build provenance: `cat /etc/iso-build-info`
            Remote access: sshd is up; warby user trusts cluster keys.

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
