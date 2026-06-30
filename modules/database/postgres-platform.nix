_: {
  flake.nixosModules.postgresInfra =
    { config, lib, pkgs, ... }:
    let
      cfg = config.services.infra.postgres;
    in
    {
      options.services.infra.postgres = {
        enable = lib.mkEnableOption "infra PostgreSQL";

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.postgresql_16;
        };

        databases = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "maya"
            "authentik"
            "langfuse"
          ];
        };

        enableReplication = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Configure streaming replication (primary role).";
        };
      };

      config = lib.mkIf cfg.enable {
        services.postgresql = {
          enable = true;
          inherit (cfg) package;
          enableTCPIP = true;

          extensions = ps: with ps; [ pgvector ];

          settings =
            if config.infra.demo.enable then
              {
                listen_addresses = lib.mkForce "localhost";
                shared_preload_libraries = lib.mkDefault "vector";
                max_connections = lib.mkDefault 50;
                shared_buffers = lib.mkDefault "256MB";
                effective_cache_size = lib.mkDefault "1GB";
                work_mem = lib.mkDefault "8MB";
                maintenance_work_mem = lib.mkDefault "64MB";
                wal_level = lib.mkDefault "replica";
              }
            else
              {
                listen_addresses = lib.mkDefault "*";
                shared_preload_libraries = lib.mkDefault "vector";
                max_connections = lib.mkDefault 100;
                shared_buffers = lib.mkDefault "2GB";
                effective_cache_size = lib.mkDefault "6GB";
                work_mem = lib.mkDefault "16MB";
                maintenance_work_mem = lib.mkDefault "256MB";
                wal_level = lib.mkDefault "replica";
                max_wal_size = lib.mkDefault "2GB";
                min_wal_size = lib.mkDefault "256MB";
              };

          authentication = ''
            local all all                                 peer
            host  all all 127.0.0.1/32                    scram-sha-256
            host  all all ::1/128                         scram-sha-256
            host  all all 100.64.0.0/10                   scram-sha-256
          '';

          ensureDatabases = cfg.databases;

          ensureUsers = [
            {
              name = "warby";
              ensureClauses = {
                superuser = true;
                createdb = true;
                createrole = true;
                login = true;
              };
            }
          ];
        };

        networking.firewall.interfaces."tailscale0".allowedTCPPorts = lib.mkAfter [ 5432 ];
      };
    };
}
