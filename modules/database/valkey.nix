_: {
  flake.nixosModules.valkeyInfra =
    { config, lib, pkgs, ... }:
    let
      cfg = config.services.infra.valkey;
      dataDir = "/var/lib/valkey";
    in
    {
      options.services.infra.valkey = {
        enable = lib.mkEnableOption "infra Valkey (Redis-compatible cache)";

        bind = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1 ::1";
          description = "Addresses Valkey listens on.";
        };

        port = lib.mkOption {
          type = lib.types.port;
          default = 6379;
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ pkgs.valkey ];

        systemd.services.valkey = {
          description = "Valkey in-memory data store";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "notify";
            ExecStart = "${lib.getExe pkgs.valkey} --bind ${cfg.bind} --port ${toString cfg.port} --dir ${dataDir} --appendonly yes";
            Restart = "on-failure";
            RestartSec = "5s";
            StateDirectory = "valkey";
            DynamicUser = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            NoNewPrivileges = true;
          };
        };

        networking.firewall.interfaces."tailscale0".allowedTCPPorts = lib.mkAfter [ cfg.port ];
      };
    };
}
