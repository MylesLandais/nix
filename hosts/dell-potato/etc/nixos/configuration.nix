# /etc/nixos/configuration.nix

{
  config,
  pkgs,
  lib,
  ...
}:

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

    settings = {
      trusted-users = [
        "root"
        "warby"
        "@wheel"
      ];

      max-jobs = 3;
      cores = 3;

      substituters = [
        "https://cache.nixos.org"
        "https://nyx.chaotic.cx"
      ];

      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nyx.chaotic.cx-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
      ];

      sandbox = true;
      auto-optimise-store = true;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };
  };
  # Boot configuration
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    kernelParams = [
      "amdgpu.si_support=1"
      "amdgpu.cik_support=1"
      "radeon.si_support=0"
      "radeon.cik_support=0"
    ];

    # Use CachyOS kernel for better desktop responsiveness and performance
    kernelPackages = pkgs.linuxPackages_cachyos;
  };

  # Network configuration
  networking = {
    hostName = "dell-potato";
    networkmanager.enable = true;
  };

  # Internationalization
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  # --- CORRECTED DESKTOP ENVIRONMENT ---
  # You had both GNOME and KDE Plasma enabled, which causes conflicts.
  # Since you are using GDM (GNOME's Display Manager), KDE has been removed
  # to ensure a stable desktop session.
  services = {
    xserver.enable = true;
    displayManager.gdm.enable = true;
    desktopManager.gnome.enable = true;
    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
    sunshine.enable = true;
    # GNOME power management settings to prevent automatic suspend and lock screen
    gnome.gnome-settings-daemon.enable = true;
    # Enable sched-ext schedulers for better responsiveness with CachyOS kernel
    scx.enable = true;
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = true;
        PermitRootLogin = "no";
      };
    };
  };

  # --- XDG PORTAL CONFIGURATION FOR GNOME ---
  # This is required for modern applications, including RustDesk screen sharing,
  # to correctly interface with the desktop environment.
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };

  # Audio configuration
  security.rtkit.enable = true;

  # Graphics support - Intel integrated + AMD discrete GPU (when present)
  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        mesa
        intel-media-driver # Intel VA-API driver
        vaapiVdpau # VA-API/VDPAU wrapper
        libvdpau-va-gl # VDPAU driver with OpenGL/VAAPI backend

        # AMD-specific packages (conditionally loaded)
        rocmPackages.clr.icd # ROCm OpenCL
        libva # VA-API
        vulkan-loader # Vulkan ICD
      ];
    };
  };

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
  virtualisation = {
    docker.enable = true;
    oci-containers = {
      containers = {
        portainer.environment.TZ = "America/New_York";
        "code-server".environment.TZ = "America/New_York";
      };
    };
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
    openssl

    # Web browsers
    firefox
    ungoogled-chromium
    brave
    ghostty
    opencode
    vesktop
    bitwarden-desktop

    # Development tools
    vscode # VS Code for development work

    # System utilities
    gparted
    xwayland
    xpra

    # AMD graphics debugging tools
    glxinfo
    vulkan-tools
    clinfo
    amdgpu_top
    libva-utils
  ];

  # Disable SSH askPassword conflicts
  programs.ssh.askPassword = "";

  # Firewall configuration - open ports for Portainer (9000) and code-server (8080)
  networking.firewall.allowedTCPPorts = [
    9000
    8080
  ];

  # Power management - prevent sleep and enable Wake-on-LAN
  powerManagement.enable = lib.mkForce false;
  systemd = {
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
    sleep.extraConfig = ''
      AllowSuspend=no
      AllowHibernation=no
      AllowHybridSleep=no
      AllowSuspendThenHibernate=no
    '';
  };

  # Disable systemd suspend/hibernation system-wide

  # Enable Wake-on-LAN
  networking.interfaces.enp0s31f6.wakeOnLan.enable = true;

  # AMD graphics kernel parameters (for when AMD GPU is present)

  # Environment variables for AMD graphics
  environment.sessionVariables = {
    AMD_VULKAN_ICD = "RADV";
    ROCR_VISIBLE_DEVICES = "all";
  };

  # System state version
  system.stateVersion = "24.11";

  security.pki.certificates = [
    ''
      -----BEGIN CERTIFICATE-----
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
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  programs.chromium = {
    enable = true;
    extensions = [
      "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
      "djnghjlejbfgnbnmjfgbdaebfbiklpha" # Kanagawa
    ];
  };

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

}
