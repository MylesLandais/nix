# LaCie NixOS Configuration
# Portable Hyprland workstation. Boots from LaCie live_nix partition.
# systemd-boot with canTouchEfiVariables=false to avoid polluting host NVRAM.

{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

let
  grubTheme = pkgs.callPackage ../../modules/features/grub-theme {};
in
{
  imports = [
    ./hardware-configuration.nix
    ./hermes.nix
    ../../modules/gnome-keyring.nix
  ];

  # ---------------------------------------------------------------------------
  # Nix
  # ---------------------------------------------------------------------------

  nix = {
    settings = {
      substituters = [
        "https://nix-community.cachix.org/"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
      experimental-features = [ "nix-command" "flakes" ];
      trusted-users = [ "root" "warby" "@wheel" ];
    };
    optimise.automatic = true;
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 3d";
    };
  };

  nixpkgs.config.allowUnfree = true;

  # ---------------------------------------------------------------------------
  # Boot — USB portable settings
  # ---------------------------------------------------------------------------

  boot = {
    plymouth.enable = true;
    consoleLogLevel = 3;
    initrd.verbose = false;
    loader = {
      efi.canTouchEfiVariables = false;
      efi.efiSysMountPoint = "/boot";
      grub = {
        enable = true;
        device = "nodev";
        efiSupport = true;
        efiInstallAsRemovable = true;
        copyKernels = false;
        useOSProber = false;
        theme = grubTheme;
        font = "${grubTheme}/JetBrainsMono.pf2";
        splashImage = null;
        # ISO loopback entries — place ISOs on the lacie_isos partition using
        # these exact filenames. Each entry chainloads the ISO's own grub.cfg
        # to avoid hardcoding kernel/initrd store paths.
        extraEntries = ''
          menuentry "Home Office Installer (NixOS)" --class nixos {
            search --no-floppy --label --set=isopart lacie_isos
            loopback loop ($isopart)/home-office-installer.iso
            set root=(loop)
            configfile /boot/grub/grub.cfg
          }

          menuentry "NixOS Graphical Live" --class nixos {
            search --no-floppy --label --set=isopart lacie_isos
            loopback loop ($isopart)/nixos-latest-graphical.iso
            set root=(loop)
            configfile /boot/grub/grub.cfg
          }

          menuentry "Kali Linux Live" --class linux {
            search --no-floppy --label --set=isopart lacie_isos
            loopback loop ($isopart)/kali-live-latest.iso
            set root=(loop)
            configfile /boot/grub/grub.cfg
          }

          menuentry "Reboot" --class restart {
            reboot
          }

          menuentry "Shutdown" --class shutdown {
            halt
          }
        '';
      };
    };
    kernelParams = [
      # Give USB controller time to enumerate before root mount.
      "rootwait"
      "quiet"
      "udev.log_level=3"
      "systemd.show_status=auto"
    ];
    kernelModules = [ "uinput" ];
    supportedFilesystems = [ "ntfs" "exfat" ];
  };

  # ---------------------------------------------------------------------------
  # Locale and Time
  # ---------------------------------------------------------------------------

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # ---------------------------------------------------------------------------
  # Networking
  # ---------------------------------------------------------------------------

  networking.networkmanager = {
    enable = true;
    plugins = with pkgs; [ networkmanager-openvpn ];
  };

  services.tailscale.enable = true;

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    settings.KbdInteractiveAuthentication = false;
  };

  # ---------------------------------------------------------------------------
  # Display and Desktop
  # ---------------------------------------------------------------------------

  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  programs.hyprland.enable = true;
  services.displayManager.sessionPackages = [ pkgs.hyprland ];

  # Auto-login for portable/guest use — no password prompt at boot.
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
        user = "greeter";
      };
      initial_session = {
        command = "Hyprland";
        user = "warby";
      };
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
    config = {
      common.default = [ "hyprland" "gtk" ];
      hyprland."org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    };
  };

  systemd.user.services.hyprland-session = {
    description = "Hyprland Wayland Session";
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = "${pkgs.systemd}/bin/systemctl --user import-environment DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP";
    };
  };

  # ---------------------------------------------------------------------------
  # Audio (PipeWire)
  # ---------------------------------------------------------------------------

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # ---------------------------------------------------------------------------
  # Bluetooth
  # ---------------------------------------------------------------------------

  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # ---------------------------------------------------------------------------
  # User
  # ---------------------------------------------------------------------------

  users.users.warby = {
    isNormalUser = true;
    extraGroups = [ "audio" "input" "networkmanager" "render" "video" "wheel" ];
    # No SSH authorized keys — add via vault/trust bootstrap separately.
    # No password set — access via auto-login only.
    initialHashedPassword = "";
  };

  # Allow passwordless sudo for wheel on portable device.
  security.sudo.wheelNeedsPassword = false;

  # ---------------------------------------------------------------------------
  # System Packages
  # ---------------------------------------------------------------------------

  environment.systemPackages = with pkgs; [
    git
    wget
    curl
    vim
    htop
    usbutils
    pciutils
    networkmanagerapplet
    mixxx
  ];

  system.stateVersion = "25.05";
}
