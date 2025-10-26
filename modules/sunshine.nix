{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.sunshine;
in
{
  options.services.sunshine = {
    enable = mkEnableOption "Sunshine game streaming server";

    package = mkOption {
      type = types.package;
      default = pkgs.sunshine;
      description = "Sunshine package to use";
    };

    user = mkOption {
      type = types.str;
      default = "sunshine";
      description = "User to run Sunshine as";
    };

    group = mkOption {
      type = types.str;
      default = "sunshine";
      description = "Group to run Sunshine as";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall ports for Sunshine";
    };

    capSysAdmin = mkOption {
      type = types.bool;
      default = true;
      description = "Grant CAP_SYS_ADMIN capability for screen capture";
    };
  };

  config = mkIf cfg.enable {
    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      inherit (cfg) group;
      description = "Sunshine game streaming user";
    };

    users.groups.${cfg.group} = { };

    # Add user to necessary groups for screen capture
    users.users.${cfg.user}.extraGroups = [
      "video"
      "input"
      "audio"
    ];

    # Install package
    environment.systemPackages = [ cfg.package ];

    # Systemd service
    systemd.services.sunshine = {
      description = "Sunshine Game Streaming Server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cfg.package}/bin/sunshine";
        Restart = "on-failure";
        RestartSec = "5s";

        # Environment variables for Wayland/GNOME compatibility
        Environment = [
          "XDG_SESSION_TYPE=wayland"
          "QT_QPA_PLATFORM=wayland"
          "GDK_BACKEND=wayland"
        ];

        # Capabilities for screen capture
        AmbientCapabilities = mkIf cfg.capSysAdmin [ "CAP_SYS_ADMIN" ];
        CapabilityBoundingSet = mkIf cfg.capSysAdmin [ "CAP_SYS_ADMIN" ];

        # Security settings
        NoNewPrivileges = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [
          "/tmp"
          "/var/lib/sunshine"
        ];
        PrivateTmp = true;
        PrivateDevices = false; # Need access to video devices
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
      };
    };

    # Create state directory
    systemd.tmpfiles.rules = [
      "d /var/lib/sunshine 0755 ${cfg.user} ${cfg.group} -"
    ];

    # Firewall configuration
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [
        47984 # HTTP
        47989 # HTTPS
        47990 # Web UI
        48010 # RTSP
      ];
      allowedUDPPorts = [
        47998 # Video
        47999 # Control
        48000 # Audio
        48002 # Microphone
      ];
    };

    # Udev rules for input devices (optional, for better input capture)
    services.udev.extraRules = ''
      KERNEL=="uinput", GROUP="${cfg.group}", MODE="0660"
    '';

    # Polkit rules for screen capture permissions (GNOME/Wayland)
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.portal.desktop.request" &&
            subject.user == "${cfg.user}") {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
