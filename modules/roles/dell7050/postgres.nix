{
  dell7050.postgres =
    # Shared PostgreSQL setup of the Dell 7050 nodes. `tuning` carries each
    # node's memory and WAL sizing.
    { tuning }:
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
          wal_level = "replica";
        }
        // tuning;

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
