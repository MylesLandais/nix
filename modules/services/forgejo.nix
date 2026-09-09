_: {
  flake.modules.nixos.forgejo =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.infra.forgejo;
      runtime = with pkgs; [
        bash
        coreutils
        docker
        docker-compose
        gnugrep
        findutils
        gnutar
        gzip
        util-linux
        openssl
        iproute2
        iptables
        jq
      ];
      script =
        name: text:
        pkgs.writeShellScript name ''
          export PATH=${lib.makeBinPath runtime}
          set -euo pipefail
          ${text}
        '';
      compose = script "forgejo-compose" ''
        unset DOMAIN POSTGRES_USER POSTGRES_DB DB_PASSWORD FORGEJO_SECRET_KEY TUNNEL_TOKEN TAILSCALE_ADDRESS
        exec docker compose --project-name forgejo --file /etc/forgejo/compose.yaml \
          --env-file /etc/forgejo/.env.tf --env-file /etc/forgejo/.env.local "$@"
      '';
      prepare = script "forgejo-prepare" ''
        umask 077
        install -d -m 0700 /etc/forgejo /var/lib/forgejo /var/backups/forgejo
        if ! test -e /etc/forgejo/.env.local; then
          if test -e /var/lib/forgejo/postgres/PG_VERSION || test -e /var/lib/forgejo/conf/app.ini || test -e /var/lib/forgejo/data/custom/conf/app.ini; then
            echo 'Existing data requires restoring its original .env.local' >&2; exit 1
          fi
          tmp=$(mktemp /etc/forgejo/.env.local.XXXXXX)
          trap 'rm -f "$tmp"' EXIT
          printf 'DB_PASSWORD=%s\nFORGEJO_SECRET_KEY=%s\n' "$(openssl rand -hex 32)" "$(openssl rand -hex 32)" > "$tmp"
          mv "$tmp" /etc/forgejo/.env.local
        fi
        if ! test -e /etc/forgejo/.env.tf; then
          printf 'DOMAIN=git.nebula-1.com\nPOSTGRES_USER=forgejo\nPOSTGRES_DB=forgejo\nTUNNEL_TOKEN=\nTAILSCALE_ADDRESS=${cfg.tailnetAddress}\n' > /etc/forgejo/.env.tf
        fi
        chmod 0600 /etc/forgejo/.env.tf /etc/forgejo/.env.local
        install -d -m 0750 -o 1000 -g 1000 /var/lib/forgejo/data /var/lib/forgejo/conf
        if ! test -e /var/lib/forgejo/conf/app.ini && test -f /var/lib/forgejo/data/custom/conf/app.ini; then
          install -m 0600 -o 1000 -g 1000 /var/lib/forgejo/data/custom/conf/app.ini /var/lib/forgejo/conf/app.ini
        fi
        # The PostgreSQL entrypoint assigns its image-specific UID on first start.
        if ! test -d /var/lib/forgejo/postgres; then install -d -m 0700 /var/lib/forgejo/postgres; fi
      '';
      up = script "forgejo-up" ''
        for attempt in $(seq 1 60); do
          if ip -4 address show dev tailscale0 | grep -Fq '${cfg.tailnetAddress}/'; then
            exec ${compose} up -d --wait --wait-timeout 240 postgres forgejo
          fi
          sleep 2
        done
        echo 'Tailscale address did not become ready' >&2; exit 1
      '';
      firewall = script "forgejo-firewall" ''
        iptables -w -N FORGEJO-IN 2>/dev/null || true
        iptables -w -F FORGEJO-IN
        iptables -w -A FORGEJO-IN -m conntrack --ctstate ESTABLISHED,RELATED -j RETURN
        iptables -w -A FORGEJO-IN -i br-forgejo -j RETURN
        iptables -w -A FORGEJO-IN -i tailscale0 -p tcp --dport 2222 -j RETURN
        iptables -w -A FORGEJO-IN -j DROP
        while iptables -w -C FORWARD -o br-forgejo -j FORGEJO-IN 2>/dev/null; do
          iptables -w -D FORWARD -o br-forgejo -j FORGEJO-IN
        done
        iptables -w -I FORWARD 1 -o br-forgejo -j FORGEJO-IN
      '';
    in
    {
      options.services.infra.forgejo = {
        enable = lib.mkEnableOption "Forgejo with manually approved public registration";
        tailnetAddress = lib.mkOption {
          type = lib.types.str;
          default = "100.123.116.99";
        };
      };
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
        networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2222 ];
        systemd.services.docker.postStart = "${firewall}";
        systemd.services.forgejo = {
          description = "Forgejo and PostgreSQL";
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
              prepare
              firewall
            ];
            ExecStart = up;
            ExecStop = "${compose} stop forgejo postgres";
            TimeoutStartSec = 600;
          };
        };
        systemd.services.forgejo-tunnel = {
          description = "Forgejo Cloudflare Tunnel (requires bootstrap administrator)";
          wantedBy = [ "multi-user.target" ];
          requires = [ "forgejo.service" ];
          after = [ "forgejo.service" ];
          partOf = [ "forgejo.service" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecCondition = script "forgejo-tunnel-ready" ''
              test -f /etc/forgejo/admin-ready
              grep -q '^TUNNEL_TOKEN=.' /etc/forgejo/.env.tf
            '';
            ExecStart = "${compose} up -d cloudflared";
            ExecStop = "${compose} stop cloudflared";
          };
        };
        systemd.services.forgejo-backup = {
          description = "Consistent Forgejo backup";
          after = [ "forgejo.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = script "forgejo-backup" (builtins.readFile ../../infra/forgejo/backup.sh);
          };
        };
        systemd.timers.forgejo-backup = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "*-*-* 03:00:00 America/Chicago";
            Persistent = true;
            Unit = "forgejo-backup.service";
          };
        };
        environment.etc = {
          "forgejo/compose.yaml".source = ../../infra/forgejo/compose.yaml;
          "forgejo/compose".source = compose;
          "forgejo/backup".source = script "forgejo-backup" (builtins.readFile ../../infra/forgejo/backup.sh);
          "forgejo/restore-check".source = script "forgejo-restore-check" (
            builtins.readFile ../../infra/forgejo/restore-check.sh
          );
          "forgejo/bootstrap-admin".source = script "forgejo-bootstrap-admin" (
            builtins.readFile ../../infra/forgejo/bootstrap-admin.sh
          );
        };
      };
    };
}
