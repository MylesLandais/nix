{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.host.syncthing.enable {
    services.syncthing = {
      enable = true;
      user = "warby";
      dataDir = "/home/warby/.local/share/syncthing";
      configDir = "/home/warby/.config/syncthing";

      # Manage devices through NixOS config, but allow manual folder management
      # This allows auto-accepted folders from trusted devices (Hydra) while
      # still being able to declaratively define folders when needed
      overrideDevices = true;
      overrideFolders = false; # Set to false to allow auto-accepted folders

      settings = {
        # GUI configuration - accessible on local network
        gui = {
          enabled = true;
          address = "0.0.0.0:8384"; # Listen on all interfaces for network access
          user = "warby";
        };

        # Device configuration
        devices = {
          # Hydra (Unraid server) - source of the "Obsidian vault" share
          "hydra" = {
            id = "L2FZYMW-J65PV4B-U23SBTT-F6N6S6Z-2J3KHGW-XJPDWQG-LB4TGBU-Z72XYAF";
            addresses = [ "dynamic" ]; # Use automatic discovery
            autoAcceptFolders = true; # Automatically accept folder shares from Hydra
          };

          # iPad
          "ipad" = {
            id = "IZ4KJMN-ZCOMH75-ZTRUVI2-PWT7HYH-D7NUDSB-SUESE2K-DBUMZ5C-HOQB4AC";
            addresses = [ "dynamic" ]; # Use automatic discovery
            autoAcceptFolders = false; # Only auto-accept from trusted source (Hydra)
          };
        };

        # Folder configuration - Automatically join existing "Obsidian vault" share
        folders = {
          # Existing "Obsidian vault" share - using the exact folder ID from Hydra
          # This will automatically join the existing share without manual steps
          "obsidian-vault" = {
            path = "/home/warby/Notes";
            id = "nzep2-ux6xz"; # Existing folder ID - must match exactly
            label = "Obsidian vault"; # Display label matching the existing share
            devices = [
              "hydra"
              "ipad"
            ];

            # Folder options matching the existing share configuration
            ignorePerms = false; # Preserve permissions
            rescanIntervalS = 3600; # Scan every hour
            fsWatcherEnabled = true; # Enable filesystem watching
            fsWatcherDelayS = 10; # Delay before processing changes

            # File versioning - keep old versions for 30 days (matching existing share)
            versioning = {
              type = "staggered";
              params = {
                cleanInterval = "3600";
                maxAge = "2592000"; # 30 days in seconds
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

    networking.firewall = {
      allowedTCPPorts = [
        22000 # Syncthing file transfer
        8384 # Syncthing Web GUI
      ];
      allowedUDPPorts = [
        22000 # Syncthing discovery
        21027 # Syncthing local discovery
      ];
    };

    # Create Notes directory
    systemd.tmpfiles.rules = [
      "d /home/warby/Notes 0755 warby users -"
    ];

    environment.systemPackages = [ pkgs.syncthing ];
  };
}
