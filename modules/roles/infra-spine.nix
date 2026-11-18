_: {
  flake.modules.nixos.profileInfraSpine =
    { config, lib, ... }:
    {
      options.infra.spine = {
        enable = lib.mkEnableOption "infra dependency spine (Postgres, Valkey, OpenBao, Traefik, Authentik)";

        postgres = lib.mkEnableOption "PostgreSQL in spine";
        valkey = lib.mkEnableOption "Valkey in spine";
        openbao = lib.mkEnableOption "OpenBao in spine";
        traefik = lib.mkEnableOption "Traefik in spine";
        authentik = lib.mkEnableOption "Authentik in spine";
      };

      config = lib.mkIf config.infra.spine.enable {
        services.infra.postgres.enable = lib.mkDefault config.infra.spine.postgres;
        services.infra.valkey.enable = lib.mkDefault config.infra.spine.valkey;
        services.infra.openbao.enable = lib.mkDefault config.infra.spine.openbao;
        services.infra.traefik.enable = lib.mkDefault config.infra.spine.traefik;
        services.infra.authentik.enable = lib.mkDefault config.infra.spine.authentik;
        infra.secrets.enable = lib.mkDefault true;
      };
    };
}
