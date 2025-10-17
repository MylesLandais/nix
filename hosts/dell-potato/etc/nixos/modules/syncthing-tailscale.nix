{ config, pkgs, ... }:

{
  # Syncthing + Tailscale Integration Module
  # This module configures Syncthing to work seamlessly over Tailscale VPN
  # Includes power management to keep the machine awake

  # Enable and configure Tailscale
  services = {
    # Disable automatic suspend
    logind = {
      settings = {
        Login = {
          HandleSuspendKey = "ignore";
          HandleHibernateKey = "ignore";
          HandleLidSwitch = "ignore";
          HandleLidSwitchDocked = "ignore";
          HandleLidSwitchExternalPower = "ignore";
          IdleAction = "ignore";
        };
      };
    };

    tailscale = {
      enable = true;
      useRoutingFeatures = "client";
    };

    # Enable and configure Syncthing for the warby user
    syncthing = {
      enable = true;
      user = "warby";
      dataDir = "/home/warby/.local/share/syncthing";
      configDir = "/home/warby/.config/syncthing";

      # Override the default listening addresses to bind to all interfaces
      # This allows Syncthing to listen on both local and Tailscale interfaces
      overrideDevices = true; # Manage devices through NixOS config
      overrideFolders = true; # Manage folders through NixOS config

      settings = {
        # GUI configuration - accessible only locally
        gui = {
          enabled = true;
          address = "127.0.0.1:8384";
          user = "warby";
          # You can set a password with: password = "your-password-hash";
        };

        # Device configuration
        devices = {
          # CachyOS machine (cerberus-ng)
          "cerberus-ng" = {
            id = "2XINVKN-2JQCEBV-OGFOHBO-6LSQRCM-J6Q3XV2-JRZZXOL-ANDNY3W-FLSUAAW";
            addresses = [
              "tcp://cerberus-ng.cerberus-bonito.ts.net:22000"
              "tcp://100.112.50.54:22000"
            ];
          };

          # Unraid/Hydra machine (optional - uncomment and add device ID when ready)
          # "hydra" = {
          #   id = "YOUR-HYDRA-DEVICE-ID-HERE";
          #   addresses = [
          #     "tcp://hydra.cerberus-bonito.ts.net:22000"
          #     "tcp://100.116.206.117:22000"
          #   ];
          # };
        };

        # Folder configuration
        folders = {
          # Workspace Notes folder
          "workspace-notes" = {
            path = "/home/warby/Workspace/Notes";
            id = "workspace-notes";
            devices = [ "cerberus-ng" ]; # Add "hydra" here if you want to sync with it too

            # Folder options
            ignorePerms = false; # Preserve permissions
            rescanIntervalS = 3600; # Scan every hour

            # File versioning - keep old versions for 30 days
            versioning = {
              type = "staggered";
              params = {
                cleanInterval = "3600";
                maxAge = "2592000"; # 30 days in seconds
              };
            };
          };

          # GBA Game Backups (RetroArch saves/ROMs)
          "gba-backups" = {
            path = "/home/warby/.config/retroarch/saves/GBA";
            id = "gba-backups";
            devices = [ "cerberus-ng" ];

            # Folder options for games (one-way sync to backup)
            ignorePerms = false;
            rescanIntervalS = 300; # Scan every 5 minutes for quick saves

            # Versioning for game saves
            versioning = {
              type = "simple";
              params = {
                keep = "5"; # Keep last 5 versions
              };
            };
          };
        };

        # Options for better Tailscale integration
        options = {
          # Use local announcements and global discovery
          localAnnounceEnabled = true;
          globalAnnounceEnabled = true;

          # Enable NAT traversal (helpful even with Tailscale)
          natEnabled = true;

          # Relay configuration
          relaysEnabled = true;

          # Connection limits
          maxSendKbps = 0; # No limit
          maxRecvKbps = 0; # No limit

          # Auto upgrade
          autoUpgradeIntervalH = 12;
        };
      };
    };
  };

  # Power Management - Prevent automatic sleep/suspend
  powerManagement = {
    enable = true;
    # Prevent the system from going to sleep
    powertop.enable = false;
  };

  # Disable sleep targets
  systemd = {
    targets = {
      sleep.enable = false;
      suspend.enable = false;
      hibernate.enable = false;
      hybrid-sleep.enable = false;
    };
    # Create the Workspace/Notes directory structure
    tmpfiles.rules = [
      "d /home/warby/Workspace 0755 warby users -"
      "d /home/warby/Workspace/Notes 0755 warby users -"
    ];
  };

  # Firewall configuration for Syncthing
  networking = {
    firewall = {
      # Allow Syncthing ports
      allowedTCPPorts = [
        22000 # Syncthing file transfer
        8384 # Syncthing Web GUI (localhost only, but opened for completeness)
      ];
      allowedUDPPorts = [
        22000 # Syncthing discovery
        21027 # Syncthing local discovery
        9 # Wake-on-LAN (WOL magic packets)
      ];

      # Allow Tailscale
      trustedInterfaces = [ "tailscale0" ];

      # Optionally, you can allow all traffic from Tailscale network
      extraCommands = ''
        iptables -A INPUT -i tailscale0 -j ACCEPT
      '';
    };
  };

  # User permissions
  users.users.warby.extraGroups = [
    # Additional groups if needed
  ];

  # Install useful packages for debugging and management
  environment.systemPackages = with pkgs; [
    syncthing
    tailscale
    ethtool # For checking/enabling WOL
  ];
}
