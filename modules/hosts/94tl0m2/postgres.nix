_: {
  flake.nixosModules.tl0m2Postgres =
    { pkgs, ... }:
    {
      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_16;
        enableTCPIP = true;

        extensions = ps: with ps; [ pgvector ];

        settings = {
          listen_addresses = "*";
          shared_preload_libraries = "vector";
          max_connections = 100;
          shared_buffers = "4GB";
          effective_cache_size = "12GB";
          work_mem = "32MB";
          maintenance_work_mem = "512MB";
          wal_level = "replica";
          max_wal_size = "4GB";
          min_wal_size = "512MB";
          max_wal_senders = 10;
          wal_keep_size = "1GB";
        };

        authentication = ''
          local all all                                 peer
          host  all all 127.0.0.1/32                    scram-sha-256
          host  all all ::1/128                         scram-sha-256
          host  all all 100.64.0.0/10                   scram-sha-256
        '';

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

      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 5432 ];
    };
}
