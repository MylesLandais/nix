_: {
  flake.modules.nixos.profileDemoCerberus =
    { config, lib, ... }:
    {
      config = lib.mkIf config.infra.demo.enable {
        infra.baseDomain = lib.mkDefault "homelab.lan";
        infra.acmeEmail = lib.mkDefault null;

        infra.spine = {
          enable = true;
          postgres = true;
          valkey = true;
          openbao = true;
          traefik = true;
          authentik = true;
        };

        infra.ingress = {
          enable = lib.mkDefault true;
          localRoutes.tint = {
            domain = "tint.localhost";
            internalPort = 45173;
          };
        };
        services.infra.traefik.demoMode = lib.mkDefault true;
        services.infra.pyload.enable = lib.mkDefault true;
        services.infra.pyload.ingress.traefik.entrypoint = lib.mkDefault "web";
        services.infra.mayaWorker.enable = lib.mkDefault true;
      };
    };
}
