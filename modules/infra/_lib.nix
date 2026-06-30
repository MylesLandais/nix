{ lib }:
let
  inherit (lib) types mkOption mkEnableOption;
in
{
  mkServiceOptions =
    {
      name,
      domain ? "${name}.homelab.lan",
      authentik ? true,
      openbao ? false,
      traefik ? true,
    }:
    {
      enable = mkEnableOption "infra service ${name}";

      domain = mkOption {
        type = types.str;
        default = domain;
        description = "Public hostname for ${name}.";
      };

      ingress = {
        traefik = {
          enable = mkOption {
            type = types.bool;
            default = traefik;
            description = "Expose ${name} via Traefik.";
          };
          entrypoint = mkOption {
            type = types.str;
            default = "websecure";
            description = "Traefik entrypoint for ${name}.";
          };
          internalPort = mkOption {
            type = types.port;
            description = "Upstream port Traefik forwards to.";
          };
        };
      };

      auth = {
        authentik = {
          enable = mkOption {
            type = types.bool;
            default = authentik;
            description = "Protect browser routes with Authentik ForwardAuth.";
          };
        };
      };

      secrets = {
        openbao = {
          enable = mkOption {
            type = types.bool;
            default = openbao;
            description = "Fetch machine credentials from OpenBao.";
          };
          paths = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "OpenBao KV paths this service may read.";
          };
        };
      };

      observability = {
        metrics = {
          enable = mkOption {
            type = types.bool;
            default = true;
          };
        };
        logs = {
          enable = mkOption {
            type = types.bool;
            default = true;
          };
        };
      };
    };
}
