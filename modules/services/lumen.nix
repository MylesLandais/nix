# CineMaya / Lumen — the `lab/` backend service.
#
# The frontend is static (pkgs.lumen-web) and is served straight from nginx by
# whichever host enables this; see modules/hosts/stage-edge/configuration.nix.
# This module only runs the Node backend that the SPA talks to over /api.
_: {
  flake.nixosModules.lumenInfra =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.infra.lumen;
    in
    {
      options.services.infra.lumen = {
        enable = lib.mkEnableOption "CineMaya (Lumen) scraper/proxy backend";

        port = lib.mkOption {
          type = lib.types.port;
          default = 3847;
          description = "Loopback port for the lab backend. Matches upstream's default.";
        };

        envFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = "/etc/lumen/env";
          description = ''
            systemd EnvironmentFile supplying TMDB_API_KEY and optionally
            WYZIE_API_KEY / OPENSUBTITLES_API_KEY. Must live outside the Nix
            store, which is world-readable. Loaded with a leading "-" so a
            missing file degrades to the offline demo catalog instead of
            blocking startup.
          '';
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.lumen-lab;
          defaultText = lib.literalExpression "pkgs.lumen-lab";
          description = "Backend package providing server.mjs.";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.lumen-lab = {
          description = "CineMaya (Lumen) lab backend";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];

          # Repo-wide convention: bound restart loops rather than letting a
          # failing unit spin (see valkey.nix / pyload.nix, added after
          # documented multi-thousand-restart incidents).
          startLimitIntervalSec = 300;
          startLimitBurst = 5;

          environment = {
            # Upstream defaults HOST to 0.0.0.0. Nothing should reach the lab
            # except nginx on the same host, so pin it to loopback — this is
            # the only thing keeping the stream proxy off the VCN interface.
            HOST = "127.0.0.1";
            PORT = toString cfg.port;
            NODE_ENV = "production";
          };

          serviceConfig = {
            ExecStart = "${pkgs.nodejs}/bin/node ${cfg.package}/server.mjs";
            WorkingDirectory = cfg.package;
            EnvironmentFile = lib.mkIf (cfg.envFile != null) [ "-${cfg.envFile}" ];

            Restart = "on-failure";
            RestartSec = "5s";

            DynamicUser = true;
            StateDirectory = "lumen";
            ProtectSystem = "strict";
            ProtectHome = true;
            NoNewPrivileges = true;
            PrivateTmp = true;
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
            ];
          };
        };
      };
    };
}
