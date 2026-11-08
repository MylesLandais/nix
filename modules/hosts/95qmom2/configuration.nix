# 95qmom2: Dell 7050 cluster node. The shared base lives in hosts/_dell7050;
# only this node's values are here.
{ config, ... }:
let
  dell = config.flake.lib.dell7050;
in
{
  flake.modules.nixos = {
    qmom2 = dell.configuration {
      hostName = "95qmom2";
      extraPackages =
        pkgs: with pkgs; [
          # forensics scan window (95qmom2 14 TB games-drive catalog)
          cifs-utils
          ntfs3g
          fclones
          sqlite
          jq
          file
        ];
    };

    qmom2Postgres = dell.postgres {
      tuning = {
        shared_buffers = "2GB";
        effective_cache_size = "6GB";
        work_mem = "16MB";
        maintenance_work_mem = "256MB";
        max_wal_size = "2GB";
        min_wal_size = "256MB";
      };
    };

    qmom2Seaweedfs = dell.seaweedfs {
      tailscaleIp = "100.107.224.21";
      rack = "95qmom2";
    };
  };
}
