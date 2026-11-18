_: {
  flake.modules.nixos.valkeyInfra =
    {
      config,
      lib,
      pkgs,
      ...
    }:
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
          # TODO(unsolved): this restarted 22474 times because a Docker container
          # (dev.valkey, from a stale duplicate crawler checkout) already held
          # 0.0.0.0:6379, so bind always failed. The ceiling below turns a permanent
          # conflict into a fast, visible failure instead of an infinite loop.
          # See docs/infra/README.md for who is supposed to own :6379.
          startLimitIntervalSec = 300;
          startLimitBurst = 5;
          serviceConfig = {
            Type = "notify";
            ExecStart = "${pkgs.valkey}/bin/valkey-server --bind ${cfg.bind} --port ${toString cfg.port} --dir ${dataDir} --appendonly yes";
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
