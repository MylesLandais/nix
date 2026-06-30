_: {
  flake.nixosModules.infraIngress =
    { config, lib, pkgs, ... }:
    let
      cfg = config.infra.ingress;
      traefikEnabled = config.services.traefik.enable;

      serviceRouters =
        lib.flatten (
          lib.mapAttrsToList (
            name: svc:
            lib.optional (
              svc.enable or false
              && svc ? ingress
              && svc.ingress.traefik.enable or false
            ) {
              inherit name;
              router = {
                rule = "Host(`${svc.domain}`)";
                service = "${name}-svc";
                entryPoints = [ svc.ingress.traefik.entrypoint ];
                middlewares =
                  lib.optional svc.auth.authentik.enable "authentik@file"
                  ++ lib.optional (svc.ingress.traefik.entrypoint == "websecure") "redirect-to-https@file";
              };
              service = {
                loadBalancer = {
                  servers = [
                    { url = "http://127.0.0.1:${toString svc.ingress.traefik.internalPort}"; }
                  ];
                };
              };
            }
          ) config.services.infra
        );
    in
    {
      options.infra.ingress = {
        enable = lib.mkEnableOption "Traefik dynamic ingress generation for infra services";

        authentikForwardAuthUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:9000/outpost.goauthentik.io/auth/traefik";
          description = "Authentik proxy outpost ForwardAuth endpoint.";
        };
      };

      config = lib.mkIf (cfg.enable && traefikEnabled) {
        services.traefik.dynamicConfigOptions = {
          http = {
            middlewares = {
              authentik = {
                forwardAuth = {
                  address = cfg.authentikForwardAuthUrl;
                  trustForwardHeader = true;
                  authResponseHeaders = [
                    "X-authentik-username"
                    "X-authentik-groups"
                    "X-authentik-email"
                    "X-authentik-name"
                    "X-authentik-uid"
                  ];
                };
              };
              "redirect-to-https" = {
                redirectScheme = {
                  scheme = "https";
                  permanent = true;
                };
              };
            };
            routers = lib.listToAttrs (
              map (
                entry:
                lib.nameValuePair "${entry.name}" (
                  entry.router
                  // lib.optionalAttrs (entry.router.entryPoints == [ "websecure" ]) { tls = { }; }
                )
              ) serviceRouters
            );
            services = lib.listToAttrs (
              map (entry: lib.nameValuePair "${entry.name}-svc" entry.service) serviceRouters
            );
          };
        };
      };
    };
}
