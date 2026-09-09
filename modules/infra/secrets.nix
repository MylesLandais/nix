_: {
  flake.modules.nixos.infraSecrets =
    { config, lib, ... }:
    let
      cfg = config.infra.secrets;
    in
    {
      options.infra.secrets = {
        enable = lib.mkEnableOption "infra secrets integration (agenix + OpenBao)";

        openbaoAddr = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:8200";
          description = "OpenBao API address for machine clients.";
        };

        openbaoMount = lib.mkOption {
          type = lib.types.str;
          default = "secret";
          description = "OpenBao KV v2 mount point.";
        };
      };

      config = lib.mkIf cfg.enable {
        environment.sessionVariables = {
          OPENBAO_ADDR = cfg.openbaoAddr;
          OPENBAO_MOUNT = cfg.openbaoMount;
        };
      };
    };
}
