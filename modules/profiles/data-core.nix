_: {
  flake.nixosModules.profileDataCore =
    { config, lib, ... }:
    {
      config = lib.mkIf (config.host.clusterRole == "data-core") {
        infra.spine = {
          enable = true;
          postgres = true;
          valkey = true;
          openbao = true;
          traefik = false;
          authentik = false;
        };
      };
    };
}
