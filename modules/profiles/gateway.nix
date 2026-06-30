_: {
  flake.nixosModules.profileGateway =
    { config, lib, ... }:
    {
      config = lib.mkIf (config.host.clusterRole == "gateway") {
        infra.spine = {
          enable = true;
          postgres = false;
          valkey = false;
          openbao = false;
          traefik = true;
          authentik = true;
        };
        infra.ingress.enable = true;
      };
    };
}
