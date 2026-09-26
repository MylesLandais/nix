_: {
  flake.nixosModules.seaweedfsInfra =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.infra.seaweedfs;
    in
    {
      options.services.infra.seaweedfs = {
        enable = lib.mkEnableOption "infra SeaweedFS (S3-compatible object storage)";

        user = lib.mkOption {
          type = lib.types.str;
          default = "warby";
          description = ''
            User to run `weed server` as. Not DynamicUser: the data directory
            predates this module (migrated off a Docker named volume by
            scripts/cutover_seaweedfs.sh in Workspace-internal) and is already
            owned by this user.
          '';
        };

        dataDir = lib.mkOption {
          type = lib.types.path;
          default = "/srv/data/seaweedfs-data";
          description = "Directory backing master/volume/filer data (masters' topology, volume files).";
        };

        s3ConfigFile = lib.mkOption {
          type = lib.types.path;
          default = "/home/warby/.local/share/seaweedfs-config/s3.json";
          description = ''
            SeaweedFS S3 identity/policy file (access keys, per-bucket grants).
            Deliberately outside the Nix store — it's an existing, already
            populated file predating this module and holds credentials.
          '';
        };

        s3Port = lib.mkOption {
          type = lib.types.port;
          default = 8333;
        };

        masterPort = lib.mkOption {
          type = lib.types.port;
          default = 9333;
        };

        volumePort = lib.mkOption {
          type = lib.types.port;
          default = 8280;
          description = ''
            Not the SeaweedFS default (8080): that collides with
            services.adguardhome's admin UI on this host. Not 8181 either —
            that's `-s3.port.iceberg`'s default (this seaweedfs release starts
            an Iceberg REST catalog alongside S3 unless told otherwise), which
            collided the same way. The Docker container this replaced never
            hit either conflict because it only ever published 8333/9333 to
            the host, never the volume port, and predated the Iceberg feature.
          '';
        };

        filerPort = lib.mkOption {
          type = lib.types.port;
          default = 8888;
        };
      };

      config = lib.mkIf cfg.enable {
        environment.systemPackages = [ pkgs.seaweedfs ];

        systemd.services.seaweedfs = {
          description = "SeaweedFS object storage (master + volume + filer + S3)";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          # Was previously the Docker container `dev.seaweedfs` (crawler/docker-compose.yml).
          # That container must stay stopped once this unit owns dataDir/the ports below —
          # same reasoning as the valkey.nix port-conflict guard.
          startLimitIntervalSec = 300;
          startLimitBurst = 5;
          # dataDir lives on a separate disk (/srv/data on cerberus, mounted
          # `nofail`). Without this the unit can start before the mount — or
          # with the disk absent — and write a fresh empty store onto the root
          # filesystem underneath the mount point.
          unitConfig.RequiresMountsFor = [ cfg.dataDir ];
          serviceConfig = {
            User = cfg.user;
            # Binds 0.0.0.0, unlike valkey's loopback-only default: Docker
            # containers on the `dev` bridge reach this via
            # `host.docker.internal` (a host-gateway route to the host's real
            # interface, not loopback), so a strict 127.0.0.1 bind would be
            # unreachable from them. Not opened on tailscale0 below, so it
            # stays off the tailnet/LAN.
            ExecStart = ''
              ${pkgs.seaweedfs}/bin/weed server \
                -dir=${cfg.dataDir} \
                -ip.bind=0.0.0.0 \
                -master.port=${toString cfg.masterPort} \
                -volume.port=${toString cfg.volumePort} \
                -filer -filer.port=${toString cfg.filerPort} \
                -s3 -s3.port=${toString cfg.s3Port} -s3.config=${cfg.s3ConfigFile} \
                -s3.port.iceberg=0
            '';
            Restart = "on-failure";
            RestartSec = "5s";
            NoNewPrivileges = true;
          };
        };
      };
    };
}
