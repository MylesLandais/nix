# Cerberus NixOS Configuration
# Host: cerberus-nix | User: warby | DE: Hyprland (Wayland)

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
    ./hardware-configuration.nix
    ./configuration-fixes.nix
    ../../modules/gaming.nix
    ../../modules/dev.nix
  ];

  # ---------------------------------------------------------------------------
  # Nix Package Manager
  # ---------------------------------------------------------------------------

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
  # Boot
  # ---------------------------------------------------------------------------

  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
    kernelPackages = pkgs.linuxPackages_cachyos;
    kernelParams = [ "usbcore.autosuspend=-1" ];
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

  networking.networkmanager.enable = true;

  # ---------------------------------------------------------------------------
  # Graphics (NVIDIA Proprietary)
  # ---------------------------------------------------------------------------

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };

  environment.sessionVariables = {
    WLR_NO_HARDWARE_CURSORS = "1";
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
  };

  # ---------------------------------------------------------------------------
  # Display and Desktop Environment
  # ---------------------------------------------------------------------------

  services.xserver.enable = true;
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  programs.hyprland.enable = true;

  services.displayManager = {
    sessionPackages = [ pkgs.hyprland ];
    sddm = {
      enable = true;
      wayland.enable = true;
      theme = lib.mkForce "sddm-astronaut-theme";
      extraPackages = with pkgs; [ sddm-astronaut ];
      settings.Theme.Current = "sddm-astronaut-theme";
    };
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs.kdePackages; [ xdg-desktop-portal-kde ];
    config.kde.default = [ "kde" ];
  };

  # Exports Wayland env vars to user systemd units
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
  # Remote Gaming (Sunshine/Moonlight)
  # ---------------------------------------------------------------------------

  services.sunshine = {
    enable = true;
    autoStart = true;
    openFirewall = true;
    capSysAdmin = true;

    # Global Sunshine settings (rendered to sunshine.conf)
    settings = {
      sunshine_name = "Cerberus Stream Host";
      min_log_level = "info";
    };

    # Declarative applications configuration (rendered to apps.json)
    # This makes the web UI read-only for app management
    applications = {
      # Global environment variables for all apps
      env = {
        PATH = "${pkgs.gamescope}/bin:${pkgs.steam}/bin:${pkgs.lib.makeBinPath [ pkgs.coreutils pkgs.bash ]}";
      };

      apps = [
        # Steam Big Picture via Gamescope (iPad Mini native resolution)
        {
          name = "Steam Big Picture (iPad Mini)";
          cmd = "${pkgs.gamescope}/bin/gamescope -w 2266 -h 1488 -r 60 -f --rt --steam -- ${pkgs.steam}/bin/steam -bigpicture";
          "prep-cmd" = [
            {
              do = "";
              undo = "setsid sh -c 'pkill -f steam.*bigpicture || true'";
            }
          ];
          "auto-detach" = "true";
          "exclude-global-prep-cmd" = "false";
        }

        # Full desktop session via Gamescope (for non-Steam VNs)
        {
          name = "Full Desktop (iPad Mini)";
          cmd = "${pkgs.gamescope}/bin/gamescope -w 2266 -h 1488 -r 60 -f --rt -- ${pkgs.hyprland}/bin/Hyprland";
          "auto-detach" = "true";
          "exclude-global-prep-cmd" = "false";
        }
      ];
    };
  };

  # mDNS discovery for Moonlight clients
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    nssmdns6 = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  # ---------------------------------------------------------------------------
  # File Sharing and Storage
  # ---------------------------------------------------------------------------

  services.samba = {
    enable = true;
    openFirewall = true;
  };

  services.gvfs.enable = true;
  services.udisks2.enable = true;
  services.tumbler.enable = true;

  # ---------------------------------------------------------------------------
  # Syncthing - File Synchronization
  # ---------------------------------------------------------------------------

  services.syncthing = {
    enable = true;
    user = "warby";
    dataDir = "/home/warby/.local/share/syncthing";
    configDir = "/home/warby/.config/syncthing";

    # Manage devices through NixOS config, but allow manual folder management
    # This allows auto-accepted folders from trusted devices (Hydra) while
    # still being able to declaratively define folders when needed
    overrideDevices = true;
    overrideFolders = false;  # Set to false to allow auto-accepted folders

    settings = {
      # GUI configuration - accessible on local network
      gui = {
        enabled = true;
        address = "0.0.0.0:8384";  # Listen on all interfaces for network access
        user = "warby";
      };

      # Device configuration
      devices = {
        # Hydra (Unraid server) - source of the "Obsidian vault" share
        "hydra" = {
          id = "L2FZYMW-J65PV4B-U23SBTT-F6N6S6Z-2J3KHGW-XJPDWQG-LB4TGBU-Z72XYAF";
          addresses = [ "dynamic" ];  # Use automatic discovery
          autoAcceptFolders = true;  # Automatically accept folder shares from Hydra
        };

        # iPad
        "ipad" = {
          id = "IZ4KJMN-ZCOMH75-ZTRUVI2-PWT7HYH-D7NUDSB-SUESE2K-DBUMZ5C-HOQB4AC";
          addresses = [ "dynamic" ];  # Use automatic discovery
          autoAcceptFolders = false;  # Only auto-accept from trusted source (Hydra)
        };
      };

      # Folder configuration - Automatically join existing "Obsidian vault" share
      folders = {
        # Existing "Obsidian vault" share - using the exact folder ID from Hydra
        # This will automatically join the existing share without manual steps
        "obsidian-vault" = {
          path = "/home/warby/Notes";
          id = "nzep2-ux6xz";  # Existing folder ID - must match exactly
          label = "Obsidian vault";  # Display label matching the existing share
          devices = [
            "hydra"
            "ipad"
          ];

          # Folder options matching the existing share configuration
          ignorePerms = false;  # Preserve permissions
          rescanIntervalS = 3600;  # Scan every hour
          fsWatcherEnabled = true;  # Enable filesystem watching
          fsWatcherDelayS = 10;  # Delay before processing changes

          # File versioning - keep old versions for 30 days (matching existing share)
          versioning = {
            type = "staggered";
            params = {
              cleanInterval = "3600";
              maxAge = "2592000";  # 30 days in seconds
            };
          };
        };
      };

      # Global options
      options = {
        # Use local announcements and global discovery
        localAnnounceEnabled = true;
        globalAnnounceEnabled = true;

        # Enable NAT traversal
        natEnabled = true;

        # Relay configuration
        relaysEnabled = true;

        # Connection limits (0 = no limit)
        maxSendKbps = 0;
        maxRecvKbps = 0;

        # Auto upgrade
        autoUpgradeIntervalH = 12;
      };
    };
  };

  # Firewall configuration for Syncthing
  networking.firewall = {
    allowedTCPPorts = [
      22000  # Syncthing file transfer
      8384   # Syncthing Web GUI
    ];
    allowedUDPPorts = [
      22000  # Syncthing discovery
      21027  # Syncthing local discovery
    ];
  };

  # Create Notes directory
  systemd.tmpfiles.rules = [
    "d /home/warby/Notes 0755 warby users -"
  ];

  # ---------------------------------------------------------------------------
  # Hardware Tweaks
  # ---------------------------------------------------------------------------

  hardware.cpu.amd.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  # Prevent USB/input devices from suspending
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/autosuspend}="0"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{power/control}="on"
    SUBSYSTEM=="input", ATTR{power/autosuspend}="0"
    SUBSYSTEM=="input", ATTR{power/control}="on"
  '';

  # nvidia-container-toolkit CDI generator workaround
  systemd.services.nvidia-container-toolkit-cdi-generator.serviceConfig.ExecStartPre = lib.mkForce null;

  # ---------------------------------------------------------------------------
  # Security and Permissions
  # ---------------------------------------------------------------------------

  security.polkit.enable = true;

  # Allow wheel group to mount filesystems without password
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
           action.id == "org.freedesktop.udisks2.filesystem-mount") &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  # Passwordless nixos-rebuild for development
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

  # ---------------------------------------------------------------------------
  # User Account
  # ---------------------------------------------------------------------------

  users.defaultUserShell = pkgs.fish;

  users.users.warby = {
    isNormalUser = true;
    description = "warby";
    extraGroups = [
      "audio"
      "docker"
      "input"
      "networkmanager"
      "render"
      "video"
      "wheel"
    ];
    packages = with pkgs; [
      neovim
      vesktop
      mpv
    ];
  };

  # ---------------------------------------------------------------------------
  # Shell
  # ---------------------------------------------------------------------------

  programs.fish.enable = true;

  # ---------------------------------------------------------------------------
  # Firefox Policy Configuration
  # ---------------------------------------------------------------------------

  environment.etc."firefox/policies/policies.json".text = builtins.toJSON {
    policies = {
      EnableMediaDRM = true;

      # Disable local storage (use Bitwarden instead)
      DisablePasswordManager = true;
      DisableDownloadSave = true;
      DisableSavePage = true;
      DisableFormHistory = true;
      DisableBuiltinPDFViewer = false;

      # Force-install extensions
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

      # Privacy hardening
      DisableFirefoxAccounts = false;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DisableTelemetry = true;
      DisableFeedbackCommands = true;
      DisableDefaultBrowserCheck = true;

      DNSOverHTTPS = {
        Enabled = true;
        ProviderURL = "https://dns.quad9.net/dns-query";
      };

      Homepage = {
        URL = "about:home";
        Locked = true;
      };
      NewTabPage = "about:home";
      Bookmarks.Enabled = false;

      AppAutoUpdate = false;
      BackgroundAppUpdate = false;
    };
  };

  # Bitwarden native messaging for Firefox
  environment.etc."firefox/native-messaging-hosts/bitwarden.json".text = ''
    {
      "name": "com.8bit.bitwarden",
      "description": "Bitwarden desktop integration",
      "path": "${pkgs.bitwarden-desktop}/bin/bitwarden-desktop",
      "type": "stdio",
      "allowed_extensions": ["{446900e4-71c2-419f-a6a7-df9c091e268b}"]
    }
  '';

  # ---------------------------------------------------------------------------
  # System Packages
  # ---------------------------------------------------------------------------

  environment.systemPackages = with pkgs; [
    # Graphics diagnostics
    libva-utils
    vulkan-tools
    vulkan-validation-layers
    egl-wayland
    nvidia-vaapi-driver

    # System utilities
    git
    cifs-utils
    ntfs3g
    polkit_gnome  # GTK polkit auth agent for keyring unlock prompts

    # Desktop theming
    papirus-icon-theme
    kdePackages.breeze-icons
    kdePackages.qtmultimedia
    adwaita-icon-theme
    sddm-astronaut

    # Applications
    bitwarden-desktop
    syncthing  # File synchronization
  ];

  # ---------------------------------------------------------------------------

  system.stateVersion = "25.05";
}
