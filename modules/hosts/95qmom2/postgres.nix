_: {
  flake.nixosModules.qmom2Postgres =
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
          shared_buffers = "2GB";
          effective_cache_size = "6GB";
          work_mem = "16MB";
          maintenance_work_mem = "256MB";
          wal_level = "replica";
          max_wal_size = "2GB";
          min_wal_size = "256MB";
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
