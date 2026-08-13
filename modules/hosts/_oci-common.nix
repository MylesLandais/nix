# Shared baseline for the Oracle Cloud aarch64 hosts (stage-edge, stage-db).
#
# Underscore-prefixed: import-tree skips it, so it is pulled in by explicit path
# from each host's module list (same convention as _mk-host.nix / _agenix.nix).
#
# These boxes are VM.Standard.A1.Flex instances on a private subnet with no
# public IP. Everything reaches them either through a Bastion port-forwarding
# session or, once enrolled, over Tailscale.
{
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    "${inputs.self}/modules/_features/ssh-keys.nix"
    inputs.self.nixosModules.tailscaleNode
    inputs.disko.nixosModules.disko
  ];

  # ---------------------------------------------------------------------------
  # Disk — wipes the Oracle boot volume entirely
  # ---------------------------------------------------------------------------
  # The stock image ships ESP + 2G xfs /boot + LVM "ocivolume" (root/oled).
  # None of that is worth preserving; disko lays down a plain GPT + ext4 root.
  # /dev/sda is correct for OCI paravirtualised block volumes (confirmed by
  # lsblk on the running instance) — these are not NVMe.
  disko.devices.disk.main = {
    device = "/dev/sda";
    type = "disk";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };

  # ---------------------------------------------------------------------------
  # Boot
  # ---------------------------------------------------------------------------
  boot = {
    loader = {
      systemd-boot.enable = true;
      # OCI firmware does not reliably persist EFI variables, so install the
      # bootloader at the removable-media path instead of registering a boot
      # entry we cannot count on surviving.
      efi.canTouchEfiVariables = false;
      efi.efiSysMountPoint = "/boot";
      systemd-boot.configurationLimit = 10;
    };

    # Serial console. On aarch64 OCI this is ttyAMA0 — keeping it is what makes
    # the instance debuggable when sshd is down, which has already happened once
    # on stage-db. Without a public IP there is no other way in.
    kernelParams = [
      "console=ttyAMA0,115200"
      "console=tty1"
    ];

    initrd.availableKernelModules = [
      "virtio_pci"
      "virtio_scsi"
      "virtio_blk"
      "virtio_net"
      "sd_mod"
    ];
  };

  # ---------------------------------------------------------------------------
  # Networking
  # ---------------------------------------------------------------------------
  networking = {
    useDHCP = lib.mkDefault true;
    firewall.enable = true;
    # Egress is via the VCN NAT gateway; the instance metadata service supplies
    # DNS. Nothing host-specific to declare.
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  # ---------------------------------------------------------------------------
  # Observability
  # ---------------------------------------------------------------------------
  # The Oracle Linux image ran a volatile journal, which is why the sshd outage
  # on stage-db could never be root-caused — the reboot that fixed it destroyed
  # the evidence. Do not repeat that.
  services.journald.storage = "persistent";
  services.journald.extraConfig = ''
    SystemMaxUse=512M
  '';

  # ---------------------------------------------------------------------------
  # Tailscale
  # ---------------------------------------------------------------------------
  # authKeyFile is placed out-of-band by nixos-anywhere --extra-files; see
  # modules/networking/tailscale.nix for why it is not an agenix secret.
  services.infra.tailscale = {
    enable = true;
    authKeyFile = "/etc/tailscale/authkey";
    extraUpFlags = [ "--advertise-tags=tag:oci-stage" ];
  };

  # ---------------------------------------------------------------------------
  # Misc
  # ---------------------------------------------------------------------------
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  # These boxes build their own closures (1 OCPU aarch64, so substitution from
  # the binary cache does the heavy lifting rather than local compilation).
  nix.settings.max-jobs = lib.mkDefault 1;

  time.timeZone = lib.mkDefault "UTC";

  environment.systemPackages = with pkgs; [
    git
    htop
    curl
  ];

  # Deploys land as root over Tailscale (`nixos-rebuild --target-host`), using
  # the keys mirrored to root by _features/ssh-keys.nix.
  users.users.warby.extraGroups = [ "wheel" ];
  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = lib.mkDefault "25.11";
}
