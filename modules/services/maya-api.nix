_: {
  flake.nixosModules.mayaApiInfra =
    { config, lib, pkgs, ... }:
    let
      infraLib = import ../infra/_lib.nix { inherit lib; };
      cfg = config.services.infra.mayaApi;
    in
    {
      options.services.infra.mayaApi = lib.recursiveUpdate
        (infraLib.mkServiceOptions {
          name = "maya-api";
          domain = "maya.homelab.lan";
          authentik = true;
          openbao = true;
        })
        {
          ingress.traefik.internalPort = lib.mkOption {
            type = lib.types.port;
            default = 8080;
          };
          workspacePath = lib.mkOption {
            type = lib.types.str;
            default = "/home/warby/Workspace-internal";
          };
        };

      config = lib.mkIf cfg.enable {
        systemd.services.maya-api = {
          description = "Maya FastAPI gateway";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            User = "warby";
            WorkingDirectory = cfg.workspacePath;
            Environment = [
              "MAYA_APP_BASE_URL=http://${cfg.domain}"
            ];
            ExecStart = "${pkgs.uv}/bin/uv run uvicorn src.maya.gateway:app --host 127.0.0.1 --port ${toString cfg.ingress.traefik.internalPort}";
            Restart = "on-failure";
          };
        };
      };
    };
}
