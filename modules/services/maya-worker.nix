_: {
  flake.nixosModules.mayaWorkerInfra =
    { config, lib, pkgs, ... }:
    let
      infraLib = import ../infra/_lib.nix { inherit lib; };
      cfg = config.services.infra.mayaWorker;
      openbaoAddr = config.infra.secrets.openbaoAddr;
      secretIdFile = "/run/agenix/maya-approle-secret-id";
    in
    {
      options.services.infra.mayaWorker = lib.recursiveUpdate
        (infraLib.mkServiceOptions {
          name = "maya-worker";
          domain = "maya-worker.homelab.lan";
          authentik = false;
          openbao = true;
          traefik = false;
        })
        {
          workspacePath = lib.mkOption {
            type = lib.types.str;
            default = "/home/warby/Workspace-internal";
          };

          openbaoRoleId = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "AppRole role_id for maya-agent (non-secret).";
          };

          discordSecretPath = lib.mkOption {
            type = lib.types.str;
            default = "maya/discord";
          };

          pyloadSecretPath = lib.mkOption {
            type = lib.types.str;
            default = "pyload/maya-agent";
          };
        };

      config = lib.mkIf cfg.enable {
        systemd.tmpfiles.rules = [
          "d /etc/maya 0755 root root - -"
        ];

        environment.etc."maya/openbao-role-id" = lib.mkIf (cfg.openbaoRoleId != "") {
          text = cfg.openbaoRoleId;
          mode = "0444";
        };

        systemd.services.maya-bot = {
          description = "Maya Discord bot (OpenBao AppRole)";
          after = [
            "network-online.target"
            "openbao.service"
          ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "simple";
            User = "warby";
            Group = "users";
            WorkingDirectory = cfg.workspacePath;
            Environment = [
              "OPENBAO_ADDR=${openbaoAddr}"
              "OPENBAO_ROLE_ID=${cfg.openbaoRoleId}"
              "OPENBAO_SECRET_ID_FILE=${secretIdFile}"
              "MAYA_DISCORD_SECRET_PATH=${cfg.discordSecretPath}"
              "MAYA_PYLOAD_SECRET_PATH=${cfg.pyloadSecretPath}"
              "PYLOAD_URL=http://127.0.0.1:8000"
              "OTEL_SERVICE_NAME=maya-bot"
            ];
            ExecStart = "${pkgs.uv}/bin/uv run maya-bot";
            Restart = "on-failure";
            RestartSec = "10s";
            PATH = "${pkgs.uv}/bin:${cfg.workspacePath}/.venv/bin";
          };
        };
      };
    };
}
