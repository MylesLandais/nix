_: {
  flake.nixosModules.infraContract =
    { lib, ... }:
    {
      options.infra = {
        baseDomain = lib.mkOption {
          type = lib.types.str;
          default = "homelab.lan";
          description = "Base domain for infra ingress routes.";
        };

        acmeEmail = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "ACME contact email for Traefik TLS certificates.";
        };

        demo = {
          enable = lib.mkEnableOption "cerberus infra demo (spine + pyload + maya worker)";
        };
      };
    };
}
