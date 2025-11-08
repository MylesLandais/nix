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
    ./configuration-fixes.nix
    ../../modules/gaming.nix
    ../../modules/dev.nix
  ];

  nix = {
    settings = {
      substituters = [
        "https://nix-community.cachix.org/"
        "https://chaotic-nyx.cachix.org/"
        "https://cache.nixos.org/"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8"
      ];

      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "warby"
        "@wheel"
      ];
    };

    optimise.automatic = true;

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 3d";
    };
  };

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
  
  # Ensure proper session handoff
  services.displayManager.sessionPackages = [ pkgs.hyprland ];

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
    powerManagement.enable = true;  # Enable power management as per fixes
    powerManagement.finegrained = false;
    open = false;  # Use proprietary driver as per fixes
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };

  boot.kernelParams = [ "usbcore.autosuspend=-1" ];  # Remove nvidia_drm.modeset=1 as per fixes

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
  # Note: This is also defined in configuration-fixes.nix, but keeping it here for redundancy
  services.udev.extraRules = ''
    # Prevent USB controller resets during session changes
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/autosuspend}="0"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="on"
    
    # Ensure input devices stay powered
    SUBSYSTEM=="input", ATTR{power/autosuspend}="0"
    SUBSYSTEM=="input", ATTR{power/control}="on"
  '';

  # Add environment variables for better NVIDIA/Wayland compatibility
  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
  };

  # Systemd user session improvements for Hyprland
  systemd.user.services.hyprland-session = {
    description = "Hyprland Wayland Session";
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = "yes";
      ExecStart = "${pkgs.systemd}/bin/systemctl --user import-environment DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP";
    };
  };

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
      "sillytavern-users"
      "sillytavern" # Add to sillytavern-users group
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
  programs.fish.enable = true;
  
  # Firefox system-wide configuration
  environment.etc."firefox/policies/policies.json".text = builtins.toJSON {
    policies = {
      # Enable DRM content
      EnableMediaDRM = true;
      
      # Disable all saving functionality
      DisablePasswordManager = true;
      DisableDownloadSave = true;
      DisableSavePage = true;
      DisableFormHistory = true;
      DisableBuiltinPDFViewer = false;
      
      # Extension management
      ExtensionSettings = {
        "ublock-origin@raymondhill.net" = {
          installation_mode = "force_installed";
          default_area = "navbar";
        };
        "bitwarden@browser" = {
          installation_mode = "force_installed";
          default_area = "navbar";
        };
      };
      
      # Security and privacy policies
      DisableFirefoxAccounts = false;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DisableFeedbackCommands = true;
      DisableDefaultBrowserCheck = true;
      
      # Network and security
      DNSOverHTTPS = {
        Enabled = true;
        ProviderURL = "https://dns.quad9.net/dns-query";
      };
      
      # Homepage and new tab
      Homepage = {
        URL = "about:home";
        Locked = true;
      };
      NewTabPage = "about:home";
      
      # Browser behavior
      Bookmarks = {
        Enabled = false;
      };
      
      # Update policies
      AppAutoUpdate = false;
      BackgroundAppUpdate = false;
    };
  };

  # Native messaging host for Bitwarden
  environment.etc."firefox/native-messaging-hosts/bitwarden.json".text = ''
    {
      "name": "com.8bit.bitwarden",
      "description": "Bitwarden desktop integration",
      "path": "${pkgs.bitwarden-desktop}/bin/bitwarden-desktop",
      "type": "stdio",
      "allowed_extensions": ["{446900e4-71c2-419f-a6a7-df9c091e268b}"]
    }
  '';
  

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
    bitwarden-desktop
    nvidia-vaapi-driver
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
