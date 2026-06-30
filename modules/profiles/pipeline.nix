_: {
  flake.nixosModules.profilePipeline =
    { config, lib, ... }:
    {
      config = lib.mkIf (config.host.clusterRole == "pipeline") {
        services.infra.pyload.enable = lib.mkDefault true;
      };
    };
}
