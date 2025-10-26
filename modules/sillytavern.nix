{ config
, lib
, pkgs
, ...
}:

with lib;

let
  cfg = config.services.sillytavern;
in
{
  options.services.sillytavern = {
    enable = mkEnableOption "SillyTavern service";

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/sillytavern";
      description = "Directory for SillyTavern data and config";
    };

    port = mkOption {
      type = types.port;
      default = 8000;
      description = "Port for SillyTavern to listen on";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      description = "Open firewall for SillyTavern port";
    };

    user = mkOption {
      type = types.str;
      default = "sillytavern";
      description = "User to run SillyTavern as";
    };

    group = mkOption {
      type = types.str;
      default = "sillytavern";
      description = "Group to run SillyTavern as";
    };
  };

  config = mkIf cfg.enable {
    # Create system user
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${cfg.group} = {};

    # OCI container configuration
    virtualisation.oci-containers.containers.sillytavern = {
      image = "ghcr.io/sillytavern/sillytavern:latest";
      ports = [ "${toString cfg.port}:8000" ];
      volumes = [
        "${cfg.dataDir}/data:/home/node/app/data"
        "${cfg.dataDir}/config:/home/node/app/config"
        "${cfg.dataDir}/plugins:/home/node/app/plugins"
        "${cfg.dataDir}/extensions:/home/node/app/public/scripts/extensions/third-party"
      ];
      environment = {
        NODE_ENV = "production";
      };
      user = "${toString config.users.users.${cfg.user}.uid}:${toString config.users.groups.${cfg.group}.gid}";
      autoStart = true;
    };

    # Firewall
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.port ];
    };

    # Activation script for initial setup
    system.activationScripts.sillytavernSetup = ''
      mkdir -p ${cfg.dataDir}/{data,config,plugins,extensions}
      chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}
    '';
  };
}