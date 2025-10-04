# /etc/nixos/configuration.nix

{ config, pkgs, lib, ... }:

{
  imports = [
    # Include the results of the hardware scan
    ./hardware-configuration.nix

    # Domain-specific configuration modules
    ./modules/media.nix
    # ./modules/syncthing-tailscale.nix
  ];
  nix = {
    settings.experimental-features = [
      "nix-command"
      "flakes"
    ];

    optimise.automatic = true;

    settings.trusted-users = [
      "root"
      "warby"
      "@wheel"
    ];

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
  # Boot configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Network configuration
  networking.hostName = "potato";
  networking.networkmanager.enable = true;

  # Internationalization
  time.timeZone = "America/New_York";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- CORRECTED DESKTOP ENVIRONMENT ---
  # You had both GNOME and KDE Plasma enabled, which causes conflicts.
  # Since you are using GDM (GNOME's Display Manager), KDE has been removed
  # to ensure a stable desktop session.
  services.xserver.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  # --- XDG PORTAL CONFIGURATION FOR GNOME ---
  # This is required for modern applications, including RustDesk screen sharing,
  # to correctly interface with the desktop environment.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };

  # Audio configuration
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Graphics support
  hardware.graphics.enable = true;

  # User configuration
  users.users.warby = {
    isNormalUser = true;
    description = "Warby";
    extraGroups = [
      "networkmanager"
      "wheel"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIONcu7pQIpReczEW77P9eW7vtte0PTVs9gGck/wyNVYZ warby@warbpad"
    ];
  };

  # Allow unfree packages globally (handled in flake.nix)

  # Core system packages
  # Changed 'rustdesk' to 'rustdesk-flutter' for better stability.
  environment.systemPackages = with pkgs; [
    # Essential system tools
    vim
    wget
    curl
    git
    htop
    rustdesk-flutter # <-- Corrected package

    # Web browsers
    firefox
    ungoogled-chromium
    ghostty
    opencode
    vesktop

    # System utilities
    gparted
  ];

  # --- CORRECTED RUSTDESK CLIENT SERVICE ---
  # The 'services.rustdesk-server' block was removed. That module is for
  # self-hosting a relay server, not for enabling remote access TO this machine.
  # This systemd service runs the RustDesk client in the background for
  # unattended remote access.
  systemd.services.rustdesk = {
    description = "RustDesk Remote Access Service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.rustdesk-flutter}/bin/rustdesk --service";
      Restart = "always";
      User = "root"; # Necessary for access on the login screen
    };
  };

  # SSH server configuration
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = true;
      PermitRootLogin = "no";
    };
  };

  # Disable SSH askPassword conflicts
  programs.ssh.askPassword = "";

  # Firewall configuration
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # networking.firewall.enable = false;

  # Power management - prevent sleep and enable Wake-on-LAN
  powerManagement.enable = lib.mkForce false;
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  # Enable Wake-on-LAN
  networking.interfaces.enp0s31f6.wakeOnLan.enable = true;

  # System state version
  system.stateVersion = "24.11";

}
