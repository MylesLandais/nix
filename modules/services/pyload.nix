_: {
  flake.nixosModules.pyloadInfra =
    { config, lib, pkgs, ... }:
    let
      infraLib = import ../infra/_lib.nix { inherit lib; };
      cfg = config.services.infra.pyload;
    in
    {
      options.services.infra.pyload = lib.recursiveUpdate
        (infraLib.mkServiceOptions {
          name = "pyload";
          domain = "downloads.homelab.lan";
          openbao = true;
        })
        {
          ingress.traefik.internalPort = lib.mkOption {
            type = lib.types.port;
            default = 8000;
          };
          dataDir = lib.mkOption {
            type = lib.types.str;
            default = "/srv/downloads";
          };
          configDir = lib.mkOption {
            type = lib.types.str;
            default = "/srv/config/pyload";
          };
        };

      config = lib.mkIf cfg.enable {
        virtualisation.podman.enable = true;

        systemd.tmpfiles.rules = [
          "d ${cfg.dataDir}       0750 warby warby - -"
          "d ${cfg.configDir}     0750 warby warby - -"
          "d ${cfg.dataDir}/incomplete 0750 warby warby - -"
        ];

        systemd.services.pyload = {
          description = "pyLoad-ng download manager";
          after = [ "network-online.target" "podman.socket" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "notify";
            Restart = "on-failure";
            RestartSec = "10s";
            ExecStartPre = [
              "-${pkgs.podman}/bin/podman rm -f pyload-ng"
              "${pkgs.podman}/bin/podman pull lscr.io/linuxserver/pyload-ng:latest"
            ];
            ExecStart = lib.escapeShellArgs [
              "${pkgs.podman}/bin/podman"
              "run"
              "--name=pyload-ng"
              "--rm"
              "-p"
              "127.0.0.1:${toString cfg.ingress.traefik.internalPort}:8000"
              "-v"
              "${cfg.configDir}:/config"
              "-v"
              "${cfg.dataDir}:/downloads"
              "lscr.io/linuxserver/pyload-ng:latest"
            ];
            ExecStop = "${pkgs.podman}/bin/podman stop -t 10 pyload-ng";
          };
        };
      };
    };
}
