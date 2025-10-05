# /etc/nixos/configuration.nix

{ config, pkgs, lib, ... }:

{
  imports = [
    # Include the results of the hardware scan
    ./hardware-configuration.nix

    # Domain-specific configuration modules
    ./modules/media.nix
    ./modules/syncthing-tailscale.nix

    ../../../../modules/dev.nix
    ../../../../modules/python.nix
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

  boot.kernelPackages = pkgs.linuxPackages_zen;

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
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # --- XDG PORTAL CONFIGURATION FOR GNOME ---
  # This is required for modern applications, including RustDesk screen sharing,
  # to correctly interface with the desktop environment.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };

  # Audio configuration
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Graphics support\n  hardware.graphics.enable = true;\n  hardware.enableRedistributableFirmware = true;\n  hardware.cpu.intel.updateMicrocode = true;

  # User configuration
  users.users.warby = {
    isNormalUser = true;
    description = "Warby";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "libvirtd"
      "qemu-libvirtd"
    ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIONcu7pQIpReczEW77P9eW7vtte0PTVs9gGck/wyNVYZ warby@warbpad"
    ];
  };

    users.groups.libvirtd.members = [ "warby" ];
    users.groups.docker.members = [ "warby" ];

    # Override TZ for containers to match potato
    virtualisation.oci-containers.containers.portainer.environment.TZ = "America/New_York";
    virtualisation.oci-containers.containers."code-server".environment.TZ = "America/New_York";


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
     openssl

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

  # Firewall configuration - open ports for Portainer (9000) and code-server (8080)
  networking.firewall.allowedTCPPorts = [ 9000 8080 ];

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

   security.pki.certificates = [
     ''-----BEGIN CERTIFICATE-----
MIIFCTCCAvGgAwIBAgIUftWnYe1SkoudcxwbAhmr4fw6vMAwDQYJKoZIhvcNAQEL
BQAwFDESMBAGA1UEAwwJbG9jYWxob3N0MB4XDTI1MTAwNTE3MDA0NVoXDTI2MTAw
NTE3MDA0NVowFDESMBAGA1UEAwwJbG9jYWxob3N0MIICIjANBgkqhkiG9w0BAQEF
AAOCAg8AMIICCgKCAgEAx0/l4tHNRrVXddQmfsO/rNJNgVK6fvgzjw2l7Ya11yQX
UYpjklRiOEyzmSYwf2c8X/AmMjR6Q6HQbfp2MOD/gz7UXcIq4KyagABHLgmWUTiQ
BNiNOYpBEnS2LtNtj1nUXJ8Ps/c/illwS8wj7wY7f8pcF9iWi6x0b6JRxFtkwL8n
JhePwCninVAEeUGluLQHuIYbFd8jmGhrECKEyUlKiYy00EvvPAZY37un2BY/if0s
yXAhFn/ON6MMRRqLQnEr8S0OGjINDnkjVjPLJn7NDkB6+fdSzvDd/fHBA1dR2u2h
DLZCIfHNWoA80+3qwN+HWihON+fMYdpYokWs9IxLGRPKS5fIeUZPBY1zG1aYWppw
4vQOSRdg8sfoD4IqgS7538PXI5DyMahw4qW+uJqBLNrvr6vMXRBIc7FgGZn5Tszd
27GdIIUGgfdQZPt2HbWMlRvGjg2rrEIAetEdmpYDRTTWmdBNkZcJLhzqE9tpmvmD
/W2OmpPAx2JkjRirIU4SnPorXfhy7ZGEtZtlRt9CSE0lB9AnLHGWigWn+IFFncW5
AP6GEij6HRLs/IR0eJkftpj/gWqjiHbUvRKYFQJlvIrZAvGcSzcshDFIPLGCb11d
JvumcPKuqCuWUNn+lXNTssTwqbtx8NRnNmJIF4zybg2Le0NQtghEoHDYmSSyuNUC
AwEAAaNTMFEwHQYDVR0OBBYEFOzGpYp6/rieTdJG9/fyBTdFozP6MB8GA1UdIwQY
MBaAFOzGpYp6/rieTdJG9/fyBTdFozP6MA8GA1UdEwEB/wQFMAMBAf8wDQYJKoZI
hvcNAQELBQADggIBAAYOYdd8782srMUSAZD5LEPveV3f2JRo1l36TnArXMfpYSq2
6tykDZPE6u22Sr/vr/5uZZqh+K3eTSijzCKeyT8qCAyQ+Piaj3jy4eZu8oWPDqnY
RDBK3jC0to6MvpfeX9pg9EhsMWteA0zADu0FIJ750lPduTamqTScsezbEdsjiwvj
9VFhb1fEZNoeKbb/KefkIyHnQcR8ge3s/2cAXZp388c6nzeL5m2v0o1xMk8u+PDu
KcMVMXn6GsPnwadSl6WVD22Bmob0sKTx2GCkscDBdm7ophYBQ6stg4JDViNBUjSJ
SqcVs2TRLAV9Jnmg2XL5l9idLOtdKfUHT5botQQ6FPSD6Og0JDXKc3NbNhvzIRKj
YzqBSzod6kCS84lZXlS+CEiwP5PfVtZgnJ8gsJGjCzi4iHJWfwyrSMA+jPfu+KaX
RL2vlBPLV80euh/Kl+YePocJuJlrN0hYQLOmNYd0JvhWH14bkcMimXqMizL9uu81
izHFF6/mgkfPkrhfzrhdlJ6HSgpahm0ejKCSbIJE03uxkirkXt5SoQaUmWAyIfLV
HGlRkeBhHNZVSB/YQDFsWo66R08EOINFRrtxU7XSlhxwwMkOMSjj4ArmOycQU/Ej
giADdXELAdf3NgclxpZfwPGubqiNrJFUVc7NqO8KTBkz8xiUA2scPAoN92Ik
-----END CERTIFICATE-----''
   ];

   security.sudo.extraRules = [
     {
       users = [ "warby" ];
       commands = [
         { command = "ALL"; options = [ "NOPASSWD" ]; }
       ];
     }
   ];

  programs.chromium = {
    enable = true;
    extensions = [
      "nngceckbapebfimnlniiiahkandclblb"  # Bitwarden
      "djnghjlejbfgnbnmjfgbdaebfbiklpha"  # Kanagawa
    ];
  };

}
