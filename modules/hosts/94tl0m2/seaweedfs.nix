_: {
  flake.nixosModules.tl0m2Seaweedfs =
    { pkgs, ... }:
    let
      # TODO: set to this node's tailnet IP after first `tailscale up` post-install.
      # Placeholder uses 0.0.0.0 so the services start; redeploy once IP is known.
      tailscaleIp = "0.0.0.0";
      masterDir = "/srv/data/seaweedfs/master";
      volumeDir = "/srv/data/seaweedfs/volume";
    in
    {
      users.groups.seaweedfs = { };
      users.users.seaweedfs = {
        isSystemUser = true;
        group = "seaweedfs";
        home = "/srv/data/seaweedfs";
        createHome = false;
      };

      systemd.tmpfiles.rules = [
        "d /srv/data/seaweedfs       0750 seaweedfs seaweedfs - -"
        "d ${masterDir}              0750 seaweedfs seaweedfs - -"
        "d ${volumeDir}              0750 seaweedfs seaweedfs - -"
      ];

      systemd.services.seaweed-master = {
        description = "SeaweedFS master";
        wants = [ "network-online.target" "tailscaled.service" ];
        after = [ "network-online.target" "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          User = "seaweedfs";
          Group = "seaweedfs";
          ExecStart = ''
            ${pkgs.seaweedfs}/bin/weed master \
              -mdir=${masterDir} \
              -ip=${tailscaleIp} \
              -ip.bind=0.0.0.0 \
              -port=9333 \
              -defaultReplication=000
          '';
          Restart = "on-failure";
          RestartSec = 5;
          ProtectSystem = "strict";
          ReadWritePaths = [ masterDir ];
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
        };
      };

      systemd.services.seaweed-volume = {
        description = "SeaweedFS volume";
        wants = [ "network-online.target" "seaweed-master.service" ];
        after = [ "network-online.target" "seaweed-master.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          User = "seaweedfs";
          Group = "seaweedfs";
          ExecStart = ''
            ${pkgs.seaweedfs}/bin/weed volume \
              -dir=${volumeDir} \
              -mserver=${tailscaleIp}:9333 \
              -ip=${tailscaleIp} \
              -ip.bind=0.0.0.0 \
              -port=8080 \
              -dataCenter=home \
              -rack=94tl0m2 \
              -max=50
          '';
          Restart = "on-failure";
          RestartSec = 5;
          ProtectSystem = "strict";
          ReadWritePaths = [ volumeDir ];
          ProtectHome = true;
          PrivateTmp = true;
          NoNewPrivileges = true;
        };
      };

      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [
        9333
        19333
        8080
        18080
      ];
    };
}
