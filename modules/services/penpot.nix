_: {
  flake.modules.nixos.penpot =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.infra.penpot;
      runtime = with pkgs; [
        bash
        coreutils
        docker
        docker-compose
        gnugrep
        gnutar
        gzip
        iproute2
        jq
        openssl
        util-linux
        config.services.tailscale.package
      ];
      script =
        name: text:
        pkgs.writeShellScript name ''
          export PATH=${lib.makeBinPath runtime}
          set -euo pipefail
          ${text}
        '';
      compose = script "penpot-compose" ''
        unset PENPOT_PUBLIC_URI PENPOT_SECRET_KEY DB_PASSWORD
        exec docker compose --project-name penpot --file /etc/penpot/compose.yaml \
          --env-file /etc/penpot/.env.local "$@"
      '';
      # Tailscale's own MagicDNS name, so the public URI follows the node rather
      # than a hostname hard-coded here.
      dnsName = ''tailscale status --json | jq -er '.Self.DNSName | rtrimstr(".")' '';
      prepare = script "penpot-prepare" ''
        umask 077
        install -d -m 0700 /etc/penpot /var/lib/penpot /var/backups/penpot
        install -d -m 0750 /var/lib/penpot/assets
        # The backend image runs as uid 1001 (penpot).
        chown 1001:1001 /var/lib/penpot/assets
        if ! test -d /var/lib/penpot/postgres; then install -d -m 0700 /var/lib/penpot/postgres; fi
        if ! test -e /etc/penpot/.env.local; then
          if test -e /var/lib/penpot/postgres/PG_VERSION; then
            echo 'Existing database requires restoring its original .env.local' >&2; exit 1
          fi
          tmp=$(mktemp /etc/penpot/.env.local.XXXXXX)
          trap 'rm -f "$tmp"' EXIT
          printf 'DB_PASSWORD=%s\nPENPOT_SECRET_KEY=%s\n' "$(openssl rand -hex 32)" "$(openssl rand -hex 48)" > "$tmp"
          mv "$tmp" /etc/penpot/.env.local
        fi
        name=$(${dnsName})
        grep -v '^PENPOT_PUBLIC_URI=' /etc/penpot/.env.local > /etc/penpot/.env.local.new || true
        echo "PENPOT_PUBLIC_URI=https://$name" >> /etc/penpot/.env.local.new
        mv /etc/penpot/.env.local.new /etc/penpot/.env.local
        chmod 0600 /etc/penpot/.env.local
      '';
      waitTailscale = script "penpot-wait-tailscale" ''
        for attempt in $(seq 1 60); do
          if ${dnsName} >/dev/null 2>&1 && ip -4 address show dev tailscale0 | grep -q 'inet 100\.'; then exit 0; fi
          sleep 2
        done
        echo 'Tailscale did not become ready' >&2; exit 1
      '';
    in
    {
      options.services.infra.penpot.enable =
        lib.mkEnableOption "Penpot with its MCP server, served over the tailnet only";

      config = lib.mkIf cfg.enable {
        virtualisation.docker = {
          enable = true;
          enableOnBoot = true;
          daemon.settings = {
            log-driver = "local";
            log-opts = {
              max-size = "10m";
              max-file = "3";
            };
          };
        };
        environment.systemPackages = [ pkgs.docker-compose ];

        systemd.services.penpot = {
          description = "Penpot (frontend, backend, exporter, MCP, PostgreSQL, Valkey)";
          wantedBy = [ "multi-user.target" ];
          requires = [ "docker.service" ];
          partOf = [ "docker.service" ];
          after = [
            "docker.service"
            "tailscaled.service"
            "network-online.target"
          ];
          wants = [
            "tailscaled.service"
            "network-online.target"
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStartPre = [
              waitTailscale
              prepare
            ];
            ExecStart = "${compose} up -d --wait --wait-timeout 420";
            ExecStop = "${compose} stop";
            TimeoutStartSec = 600;
          };
        };

        # HTTPS on the tailnet only. Penpot needs a secure context; tailscale
        # issues the certificate (HTTPS must be enabled in the tailnet admin).
        systemd.services.penpot-serve = {
          description = "Expose Penpot over tailscale serve (HTTPS)";
          wantedBy = [ "multi-user.target" ];
          requires = [ "penpot.service" ];
          after = [ "penpot.service" ];
          partOf = [ "penpot.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = script "penpot-serve-on" "tailscale serve --bg --https=443 http://127.0.0.1:9001";
            ExecStop = script "penpot-serve-off" "tailscale serve --https=443 off || true";
          };
        };

        systemd.services.penpot-backup = {
          description = "Penpot database and assets backup";
          after = [ "penpot.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = script "penpot-backup" ''
              umask 077
              exec 9>/run/penpot-backup.lock
              flock -n 9
              stamp=$(date -u +%Y%m%dT%H%M%SZ)
              tmp=$(mktemp -d /var/backups/penpot/.incomplete-XXXXXX)
              ${compose} exec -T postgres pg_dump -Fc -U penpot -d penpot > "$tmp/database.dump"
              tar -czf "$tmp/assets.tar.gz" -C /var/lib/penpot assets
              cp /etc/penpot/.env.local "$tmp/env.local"
              (cd "$tmp" && sha256sum database.dump assets.tar.gz env.local > SHA256SUMS)
              mv "$tmp" "/var/backups/penpot/$stamp"
              ls -1d /var/backups/penpot/2* | head -n -7 | xargs -r rm -rf
            '';
          };
        };
        systemd.timers.penpot-backup = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 03:30:00 America/Chicago";
            Persistent = true;
            Unit = "penpot-backup.service";
          };
        };

        environment.etc = {
          "penpot/compose.yaml".source = ../../infra/penpot/compose.yaml;
          "penpot/compose".source = compose;
        };
      };
    };
}
