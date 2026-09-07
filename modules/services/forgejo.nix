_:
{
  flake.nixosModules.forgejo = { config, lib, pkgs, ... }:
    let
      cfg = config.services.infra.forgejo;
      compose = pkgs.writeText "forgejo-compose.yaml" ''
        services:
          cloudflared:
            image: cloudflare/cloudflared:2026.8.3
            command: tunnel --no-autoupdate run --token $${TUNNEL_TOKEN}
            env_file:
              - /etc/forgejo/.env.local
            restart: unless-stopped
            networks: [forgejo]
            depends_on:
              forgejo:
                condition: service_started

          forgejo:
            image: codeberg.org/forgejo/forgejo:15.0.7-rootless
            user: "1000:1000"
            env_file:
              - /etc/forgejo/.env.local
            environment:
              USER_UID: "1000"
              USER_GID: "1000"
              FORGEJO__database__DB_TYPE: postgres
              FORGEJO__database__HOST: postgres:5432
              FORGEJO__database__NAME: $${POSTGRES_DB}
              FORGEJO__database__USER: $${POSTGRES_USER}
              FORGEJO__database__PASSWD: $${DB_PASSWORD}
              FORGEJO__database__SSL_MODE: disable
              FORGEJO__server__DOMAIN: $${DOMAIN}
              FORGEJO__server__ROOT_URL: https://$${DOMAIN}/
              FORGEJO__server__SSH_DOMAIN: $${DOMAIN}
              FORGEJO__server__SSH_PORT: "2222"
              FORGEJO__server__START_SSH_SERVER: "true"
              FORGEJO__service__DISABLE_REGISTRATION: "true"
              FORGEJO__service__REQUIRE_SIGNIN_VIEW: "true"
              FORGEJO__security__SECRET_KEY: $${FORGEJO_SECRET_KEY}
              FORGEJO__security__REVERSE_PROXY_TRUSTED_PROXIES: "172.30.42.2/32"
              FORGEJO__security__INSTALL_LOCK: "true"
            volumes:
              - /var/lib/forgejo/data:/var/lib/gitea
            ports:
              - "$${TAILSCALE_ADDRESS}:2222:2222"
            networks: [forgejo]
            restart: unless-stopped
            depends_on:
              postgres:
                condition: service_healthy

          postgres:
            image: postgres:16.15-alpine
            env_file:
              - /etc/forgejo/.env.local
            environment:
              POSTGRES_USER: $${POSTGRES_USER}
              POSTGRES_PASSWORD: $${DB_PASSWORD}
              POSTGRES_DB: $${POSTGRES_DB}
            volumes:
              - /var/lib/forgejo/postgres:/var/lib/postgresql/data
            networks: [forgejo]
            restart: unless-stopped
            healthcheck:
              test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
              interval: 10s
              timeout: 5s
              retries: 12

        networks:
          forgejo:
            ipam:
              config:
                - subnet: 172.30.42.0/24
  '';
      compose-up = pkgs.writeShellScript "forgejo-compose-up" ''
        set -euo pipefail
        test -s /etc/forgejo/.env.local
        install -d -o 1000 -g 1000 /var/lib/forgejo/data
        install -d -o 999 -g 999 /var/lib/forgejo/postgres
        exec ${pkgs.docker}/bin/docker compose --project-name forgejo --file ${compose} --env-file /etc/forgejo/.env.local up --detach
      '';
      compose-down = pkgs.writeShellScript "forgejo-compose-down" ''
        exec ${pkgs.docker}/bin/docker compose --project-name forgejo --file ${compose} --env-file /etc/forgejo/.env.local down
      '';
      backup = pkgs.writeShellScript "forgejo-backup" ''
        set -euo pipefail
        exec 9>/run/forgejo-backup.lock
        ${pkgs.util-linux}/bin/flock -n 9
        was_running=0
        if ${pkgs.docker}/bin/docker compose --project-name forgejo --file ${compose} --env-file /etc/forgejo/.env.local ps --status running --services | ${pkgs.gnugrep}/bin/grep -qx forgejo; then was_running=1; fi
        trap 'if [ "$was_running" -eq 1 ]; then ${compose-up}; fi' EXIT
        stamp=$(${pkgs.coreutils}/bin/date -u +%Y%m%dT%H%M%SZ)
        tmp=/var/backups/forgejo/.tmp-$stamp
        out=/var/backups/forgejo/forgejo-$stamp
        install -d -m 0700 /var/backups/forgejo "$tmp"
        if [ "$was_running" -eq 1 ]; then
          ${pkgs.docker}/bin/docker compose --project-name forgejo --file ${compose} --env-file /etc/forgejo/.env.local exec -T postgres sh -c 'pg_dump --format=custom -U "$POSTGRES_USER" -d "$POSTGRES_DB"' > "$tmp/forgejo.dump"
        fi
        ${compose-down}
        ${pkgs.gnutar}/bin/tar --create --file="$tmp/forgejo-data.tar" --directory=/var/lib/forgejo data
        ${pkgs.coreutils}/bin/cp /etc/forgejo/.env.local "$tmp/env.local"
        ${pkgs.coreutils}/bin/mv "$tmp" "$out"
        ${pkgs.findutils}/bin/find /var/backups/forgejo -mindepth 1 -maxdepth 1 -type d -name 'forgejo-*' -mtime +14 -exec ${pkgs.coreutils}/bin/rm -rf {} +
      '';
    in
    {
      options.services.infra.forgejo = {
        enable = lib.mkEnableOption "private Forgejo stack";
        tailnetAddress = lib.mkOption { type = lib.types.str; default = "100.123.116.99"; };
      };

      config = lib.mkIf cfg.enable {
        virtualisation.docker = { enable = true; enableOnBoot = true; };
        environment.systemPackages = [ pkgs.docker-compose ];
        systemd.tmpfiles.rules = [
          "d /etc/forgejo 0700 root root -"
          "d /var/lib/forgejo 0750 root root -"
          "d /var/backups/forgejo 0700 root root -"
        ];
        systemd.services.forgejo = {
          description = "Forgejo Docker Compose stack";
          wantedBy = [ "multi-user.target" ];
          after = [ "docker.service" "tailscaled.service" ];
          wants = [ "docker.service" "tailscaled.service" ];
          serviceConfig = { Type = "oneshot"; RemainAfterExit = true; ExecStart = compose-up; ExecStop = compose-down; }; 
        };
        systemd.services.forgejo-backup = { description = "Forgejo backup"; serviceConfig = { Type = "oneshot"; ExecStart = backup; }; };
        systemd.timers.forgejo-backup = { wantedBy = [ "timers.target" ]; timerConfig = { OnCalendar = "03:00 America/Chicago"; Persistent = true; RandomizedDelaySec = "15m"; Unit = "forgejo-backup.service"; }; };
        networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2222 ];
        networking.firewall.allowedTCPPorts = [ ];
        environment.etc."forgejo/compose.yaml".source = compose;
        environment.etc."forgejo/compose-up".source = compose-up;
        environment.etc."forgejo/compose-down".source = compose-down;
        environment.etc."forgejo/backup".source = backup;
      };
    };
}
