_: {
  flake.modules.nixos.mayaWorkerInfra =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      infraLib = import ../infra/_lib.nix { inherit lib; };
      cfg = config.services.infra.mayaWorker;
      openbaoAddr = config.infra.secrets.openbaoAddr;
      secretIdFile = "/run/agenix/maya-approle-secret-id";
    in
    {
      options.services.infra.mayaWorker =
        lib.recursiveUpdate
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
              default = "/home/warby/Workspace-git/maya-unified";
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
          # TODO(unsolved): restarted 11534 times with exit 2 — ExecStart points at
          # ${workspacePath}/apps/maya-bot, but Workspace-internal/apps does not exist
          # at all, so `uv run` could never spawn. Three maya trees are in play and
          # none is declared canonical: Workspace/src/maya (last touched 2026-07-09),
          # Workspace-git/maya-unified (2026-07-21), and this missing path. Pick one,
          # point workspacePath at it, and retire the others before re-enabling.
          startLimitIntervalSec = 300;
          startLimitBurst = 5;
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
            ExecStart = "${pkgs.uv}/bin/uv run --project ${cfg.workspacePath}/apps/maya-bot maya-bot";
            Restart = "on-failure";
            RestartSec = "10s";
            PATH = "${pkgs.uv}/bin:${cfg.workspacePath}/.venv/bin";
          };
        };
      };
    };
}
