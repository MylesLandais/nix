_: {
  flake.nixosModules.openbaoJwtAuth =
    { lib, ... }:
    {
      options.services.infra.openbaoJwtAuth = {
        enable = lib.mkEnableOption "OpenBao JWT auth for CI/CD (GitHub Actions OIDC)";

        oidcDiscoveryUrl = lib.mkOption {
          type = lib.types.str;
          default = "https://token.actions.githubusercontent.com";
          description = "OIDC issuer for GitHub Actions.";
        };

        boundAudiences = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
        };

        boundClaims = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            repository = "MylesLandais/nix";
            ref = "refs/heads/main";
          };
        };

        tokenPolicies = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ "pyload-ci" ];
        };

        tokenTtl = lib.mkOption {
          type = lib.types.str;
          default = "15m";
        };
      };

      # Implementation deferred until spine is stable; options compile for planning.
    };
}
