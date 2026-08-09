_: {
  flake.nixosModules.infraIngress =
    { config, lib, ... }:
    let
      cfg = config.infra.ingress;
      traefikEnabled = config.services.traefik.enable;

      serviceRouters = lib.flatten (
        lib.mapAttrsToList (
          name: svc:
          lib.optional (svc.enable or false && svc ? ingress && svc.ingress.traefik.enable or false) {
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

      localRouters = lib.mapAttrsToList (name: route: {
        name = "dev-${name}";
        router = {
          rule = "Host(`${route.domain}`)";
          service = "dev-${name}-svc";
          entryPoints = [ "web" ];
        };
        service = {
          loadBalancer = {
            servers = [
              { url = "http://127.0.0.1:${toString route.internalPort}"; }
            ];
          };
        };
      }) cfg.localRoutes;

      allRouters = serviceRouters ++ localRouters;
      localRouteValues = lib.attrValues cfg.localRoutes;
      localDomains = map (route: route.domain) localRouteValues;
      localPorts = map (route: route.internalPort) localRouteValues;
    in
    {
      options.infra.ingress = {
        enable = lib.mkEnableOption "Traefik dynamic ingress generation for infra services";

        authentikForwardAuthUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:9000/outpost.goauthentik.io/auth/traefik";
          description = "Authentik proxy outpost ForwardAuth endpoint.";
        };

        localRoutes = lib.mkOption {
          type = lib.types.attrsOf (
            lib.types.submodule (
              { name, ... }:
              {
                options = {
                  domain = lib.mkOption {
                    type = lib.types.str;
                    default = "${name}.localhost";
                    description = "Stable local hostname routed through Traefik.";
                  };

                  internalPort = lib.mkOption {
                    type = lib.types.port;
                    description = "Strict loopback port owned by the local repository.";
                  };
                };
              }
            )
          );
          default = { };
          description = "Explicit hostname and port registry for local development servers.";
        };
      };

      config = lib.mkIf (cfg.enable && traefikEnabled) {
        assertions = [
          {
            assertion = lib.length localDomains == lib.length (lib.unique localDomains);
            message = "infra.ingress.localRoutes domains must be unique";
          }
          {
            assertion = lib.length localPorts == lib.length (lib.unique localPorts);
            message = "infra.ingress.localRoutes internal ports must be unique";
          }
        ];

        networking.hosts."127.0.0.1" = localDomains;

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
                  entry.router // lib.optionalAttrs (entry.router.entryPoints == [ "websecure" ]) { tls = { }; }
                )
              ) allRouters
            );
            services = lib.listToAttrs (
              map (entry: lib.nameValuePair "${entry.name}-svc" entry.service) allRouters
            );
          };
        };
      };
    };
}
