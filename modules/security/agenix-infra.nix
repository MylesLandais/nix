_: {
  flake.nixosModules.agenixInfra =
    {
      config,
      inputs,
      lib,
      pkgs,
      ...
    }:
    let
      secretsDir = "${inputs.self}/secrets";
      hasOpenbaoUnseal = builtins.pathExists "${secretsDir}/openbao-unseal.age";
      hasMayaApprole = builtins.pathExists "${secretsDir}/maya-approle-secret-id.age";
      hasAuthentikKey = builtins.pathExists "${secretsDir}/authentik-secret-key.age";
    in
    {
      age.secrets = lib.mkMerge [
        (lib.mkIf (config.infra.demo.enable && hasOpenbaoUnseal) {
          openbao-unseal = {
            file = ../secrets/openbao-unseal.age;
            owner = "root";
            group = "root";
            mode = "0400";
          };
        })
        (lib.mkIf (config.infra.demo.enable && hasMayaApprole) {
          maya-approle-secret-id = {
            file = ../secrets/maya-approle-secret-id.age;
            owner = "warby";
            group = "users";
            mode = "0400";
          };
        })
        (lib.mkIf (config.infra.demo.enable && hasAuthentikKey) {
          authentik-secret-key = {
            file = ../secrets/authentik-secret-key.age;
            owner = "root";
            group = "root";
            mode = "0400";
          };
        })
      ];

      services.infra.authentik.secretKeyFile = lib.mkIf (config.infra.demo.enable && hasAuthentikKey)
        config.age.secrets.authentik-secret-key.path;

      systemd.services.openbao-unseal = lib.mkIf (config.services.infra.openbao.enable && hasOpenbaoUnseal) {
        description = "Unseal OpenBao after boot";
        after = [ "openbao.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.openbao}/bin/bao operator unseal $(cat ${config.age.secrets.openbao-unseal.path})";
        };
      };
    };
}
