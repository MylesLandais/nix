_: {
  flake.modules.nixos.stageEdge =
    { config, pkgs, inputs, ... }:
    let
      labPort = config.services.infra.lumen.port;
    in
    {
      imports = [
        "${inputs.self}/modules/hosts/_oci-common.nix"
        inputs.self.modules.nixos.lumenInfra
      ];

      networking.hostName = "stage-edge";

      # -------------------------------------------------------------------------
      # Administration
      # -------------------------------------------------------------------------
      # Password authentication is disabled in _oci-common.nix. These accounts
      # stay inaccessible until their individual SSH public keys are added.
      users.users = {
        lain = {
          isNormalUser = true;
          description = "Lain";
          hashedPassword = "!";
          extraGroups = [ "wheel" ];
          openssh.authorizedKeys.keys = [ ];
        };

        fran = {
          isNormalUser = true;
          description = "Fran";
          hashedPassword = "!";
          extraGroups = [ "wheel" ];
          openssh.authorizedKeys.keys = [ ];
        };
      };

      # -------------------------------------------------------------------------
      # CineMaya (Lumen)
      # -------------------------------------------------------------------------
      # Static SPA from nginx; everything under /api proxied to the lab backend
      # on loopback. The frontend builds all its API calls relatively and derives
      # the watch-party socket from window.location.host, so a single vhost
      # covers the whole app with no CORS and no absolute URLs to rewrite.
      services.infra.lumen.enable = true;

      services.nginx = {
        enable = true;
        recommendedGzipSettings = true;
        recommendedOptimisation = true;

        virtualHosts."stage-edge" = {
          default = true;
          root = "${pkgs.lumen-web}";

          # react-router owns the client-side routes, so unknown paths must fall
          # back to the shell rather than 404 (e.g. /watch/<id> on a hard reload).
          locations."/".tryFiles = "$uri $uri/ /index.html";

          locations."/api" = {
            proxyPass = "http://127.0.0.1:${toString labPort}";
            # /api/party is a WebSocket relay for watch-together.
            proxyWebsockets = true;
            extraConfig = ''
              # /api/proxy streams HLS/MP4. Buffering it would add latency and
              # churn memory on a 1-OCPU box, and long-lived party sockets must
              # not be reaped by the default 60s read timeout.
              proxy_buffering off;
              proxy_read_timeout 1h;
              proxy_send_timeout 1h;
            '';
          };
        };
      };

      # Tailnet-only, unchanged from the placeholder: port 80 is accepted on
      # tailscale0 and refused on the VCN interface. The lab backend is never
      # exposed — it binds 127.0.0.1 and is only reachable through nginx.
      networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 80 ];
    };
}
