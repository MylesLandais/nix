# 94tl0m2: Dell 7050 cluster node. The shared base lives in modules/roles/dell7050;
# only this node's values are here.
{ config, ... }:
let
  dell = config.flake.lib.dell7050;
in
{
  flake.modules.nixos = {
    tl0m2 = dell.configuration { hostName = "94tl0m2"; };

    tl0m2Postgres = dell.postgres {
      tuning = {
        shared_buffers = "4GB";
        effective_cache_size = "12GB";
        work_mem = "32MB";
        maintenance_work_mem = "512MB";
        max_wal_size = "4GB";
        min_wal_size = "512MB";
        max_wal_senders = 10;
        wal_keep_size = "1GB";
      };
    };

    tl0m2Seaweedfs = dell.seaweedfs {
      # TODO: set to this node's tailnet IP after first `tailscale up` post-install.
      # Placeholder uses 0.0.0.0 so the services start; redeploy once IP is known.
      tailscaleIp = "0.0.0.0";
      rack = "94tl0m2";
    };
  };
}
