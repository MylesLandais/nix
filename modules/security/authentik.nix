_: {
  flake.nixosModules.authentikInfra =
    { config, lib, pkgs, ... }:
    let
      cfg = config.services.infra.authentik;
      secretKey =
        if cfg.secretKeyFile != null then
          builtins.readFile cfg.secretKeyFile
        else
          "demo-authentik-insecure-key-replace-with-agenix-before-prod";
    in
    {
      options.services.infra.authentik = {
        enable = lib.mkEnableOption "Authentik identity provider (Podman stack)";

        domain = lib.mkOption {
          type = lib.types.str;
          default = "auth.${config.infra.baseDomain}";
        };

        secretKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "agenix-mounted Authentik secret_key file.";
        };

        postgresHost = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
        };

        valkeyHost = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1";
        };

        outpostPort = lib.mkOption {
          type = lib.types.port;
          default = 9000;
          description = "Authentik proxy outpost listen port for ForwardAuth.";
        };
      };

      config = lib.mkIf cfg.enable {
        virtualisation.podman.enable = true;

        systemd.services.authentik-server = {
          description = "Authentik server";
          after = [
            "network-online.target"
            "podman.socket"
          ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "notify";
            Restart = "on-failure";
            RestartSec = "10s";
            ExecStartPre = [
              "-${pkgs.podman}/bin/podman rm -f authentik-server"
              "${pkgs.podman}/bin/podman pull ghcr.io/goauthentik/server:latest"
            ];
            ExecStart = lib.escapeShellArgs [
              "${pkgs.podman}/bin/podman"
              "run"
              "--name=authentik-server"
              "--rm"
              "--network=host"
              "-e"
              "AUTHENTIK_SECRET_KEY=${secretKey}"
              "-e"
              "AUTHENTIK_POSTGRESQL__HOST=${cfg.postgresHost}"
              "-e"
              "AUTHENTIK_POSTGRESQL__NAME=authentik"
              "-e"
              "AUTHENTIK_POSTGRESQL__USER=authentik"
              "-e"
              "AUTHENTIK_POSTGRESQL__PASSWORD=authentik"
              "-e"
              "AUTHENTIK_REDIS__HOST=${cfg.valkeyHost}"
              "ghcr.io/goauthentik/server:latest"
              "server"
            ];
            ExecStop = "${pkgs.podman}/bin/podman stop -t 10 authentik-server";
          };
        };

        systemd.services.authentik-worker = {
          description = "Authentik worker";
          after = [ "authentik-server.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "notify";
            Restart = "on-failure";
            RestartSec = "10s";
            ExecStartPre = [
              "-${pkgs.podman}/bin/podman rm -f authentik-worker"
            ];
            ExecStart = lib.escapeShellArgs [
              "${pkgs.podman}/bin/podman"
              "run"
              "--name=authentik-worker"
              "--rm"
              "--network=host"
              "-e"
              "AUTHENTIK_SECRET_KEY=${secretKey}"
              "-e"
              "AUTHENTIK_POSTGRESQL__HOST=${cfg.postgresHost}"
              "-e"
              "AUTHENTIK_POSTGRESQL__NAME=authentik"
              "-e"
              "AUTHENTIK_POSTGRESQL__USER=authentik"
              "-e"
              "AUTHENTIK_POSTGRESQL__PASSWORD=authentik"
              "-e"
              "AUTHENTIK_REDIS__HOST=${cfg.valkeyHost}"
              "ghcr.io/goauthentik/server:latest"
              "worker"
            ];
            ExecStop = "${pkgs.podman}/bin/podman stop -t 10 authentik-worker";
          };
        };

        systemd.services.authentik-outpost = {
          description = "Authentik Traefik proxy outpost";
          after = [ "authentik-server.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "notify";
            Restart = "on-failure";
            RestartSec = "10s";
            ExecStartPre = [
              "-${pkgs.podman}/bin/podman rm -f authentik-outpost"
              "${pkgs.podman}/bin/podman pull ghcr.io/goauthentik/proxy:latest"
            ];
            ExecStart = lib.escapeShellArgs [
              "${pkgs.podman}/bin/podman"
              "run"
              "--name=authentik-outpost"
              "--rm"
              "--network=host"
              "-e"
              "AUTHENTIK_HOST=http://127.0.0.1:9000"
              "-e"
              "AUTHENTIK_INSECURE=true"
              "-e"
              "AUTHENTIK_TOKEN=placeholder-bootstrap-token"
              "-p"
              "${toString cfg.outpostPort}:9000"
              "ghcr.io/goauthentik/proxy:latest"
            ];
            ExecStop = "${pkgs.podman}/bin/podman stop -t 10 authentik-outpost";
          };
        };
      };
    };
}
