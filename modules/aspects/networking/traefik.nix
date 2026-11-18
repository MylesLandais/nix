_: {
  flake.modules.nixos.traefikInfra =
    { config, lib, ... }:
    let
      cfg = config.services.infra.traefik;
      acmeEmail = config.infra.acmeEmail;
    in
    {
      options.services.infra.traefik = {
        enable = lib.mkEnableOption "infra Traefik reverse proxy";

        demoMode = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "HTTP-only demo (no ACME / self-signed TLS).";
        };

        dashboard = lib.mkEnableOption "Traefik dashboard (internal only)";

        domain = lib.mkOption {
          type = lib.types.str;
          default = "traefik.${config.infra.baseDomain}";
        };
      };

      config = lib.mkIf cfg.enable {
        services.traefik = {
          enable = true;
          staticConfigOptions = {
            entryPoints =
              if cfg.demoMode || acmeEmail == null then
                {
                  web.address = ":80";
                }
              else
                {
                  web = {
                    address = ":80";
                    http.redirections.entryPoint = {
                      to = "websecure";
                      scheme = "https";
                    };
                  };
                  websecure.address = ":443";
                };
            api = lib.mkIf cfg.dashboard {
              dashboard = true;
              insecure = true;
            };
            certificatesResolvers.letsencrypt.acme = lib.mkIf (acmeEmail != null && !cfg.demoMode) {
              email = acmeEmail;
              storage = "/var/lib/traefik/acme.json";
              httpChallenge.entryPoint = "web";
            };
          };
        };

        networking.firewall.allowedTCPPorts =
          if cfg.demoMode then
            [ 80 ]
          else
            [
              80
              443
            ];
      };
    };
}
