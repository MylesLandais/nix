# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{
  config,
  pkgs,
  inputs,
  lib,
  extra-types,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
    ../../modules/gaming.nix
    ../../modules/dev.nix
  ];

  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  # Allow unfree packages (e.g., NVIDIA drivers)
  nixpkgs.config.allowUnfree = true;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel.
  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/Chicago";

  # Select internationalisation properties.
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

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable Hyprland
  programs.hyprland.enable = true;

  # SDDM Display Manager with Wayland support (friend's working config)
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = lib.mkForce "sddm-astronaut-theme";
    extraPackages = with pkgs; [
      sddm-astronaut
    ];
    settings = {
      Theme = {
        Current = "sddm-astronaut-theme";
      };
    };
  };

  # NVIDIA Configuration

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  boot.kernelParams = [ "nvidia_drm.modeset=1" "usbcore.autosuspend=-1" ];

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs.kdePackages; [ xdg-desktop-portal-kde ];
    config = {
      kde.default = [ "kde" ];
    };
  };

  services.samba = {
    enable = true;
    openFirewall = true;
  };

  services.sillytavern-container = {
    enable = true;
    hostAddress = "0.0.0.0";  # Allow network access for multiple users
    port = 8000;
    enableMultiUser = true;    # Enable user account management
    openFirewall = true;       # Open firewall for external access
    useContainer = true;       # Use Podman container
    imageTag = "latest";       # Consider pinning digest for production
  };

  services.gvfs.enable = true;
  services.udisks2.enable = true;

  # USB power management fixes to prevent device resets during login
  services.udev.extraRules = ''
    # Prevent USB controller resets during session changes
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/autosuspend}="0"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="on"
    
    # Ensure input devices stay powered
    SUBSYSTEM=="input", ATTR{power/autosuspend}="0"
    SUBSYSTEM=="input", ATTR{power/control}="on"
  '';

  security.polkit.enable = true;
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
           action.id == "org.freedesktop.udisks2.filesystem-mount") &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  # Define a user account. Don't forget to set a password with 'passwd'.
  users.defaultUserShell = pkgs.fish;
  
  # Create sillytavern-users group for shared data access
  users.groups.sillytavern-users = {};
  
  users.users.warby = {
    isNormalUser = true;
    description = "warby";
    extraGroups = [
      "networkmanager"
      "wheel"
      "sillytavern-users"  # Add to sillytavern-users group
    ];
    packages = with pkgs; [
      neovim
      vesktop
      mpv
      gemini-cli
      #  thunderbird
    ];
  };

  # Allow passwordless sudo for nixos-rebuild during development
  security.sudo.extraRules = [
    {
      users = [ "warby" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixos-rebuild";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  # Install firefox.
  programs.firefox.enable = true;
  programs.fish.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    libva-utils
    vulkan-tools
    vulkan-validation-layers
    egl-wayland
    git
    papirus-icon-theme
    kdePackages.breeze-icons
    kdePackages.qtmultimedia
    adwaita-icon-theme
    sddm-astronaut
    cifs-utils
    ntfs3g
  ];

  system.stateVersion = "25.05"; # Did you read the comment?

  # To mount your Windows partitions, you can add entries to fileSystems.
  # For example:
  # fileSystems."/mnt/windows" = {
  #   device = "/dev/disk/by-uuid/YOUR-WINDOWS-PARTITION-UUID";
  #   fsType = "ntfs";
  #   options = [ "rw,uid=1000,gid=100,umask=007,fmask=117" ];
  # };

}
