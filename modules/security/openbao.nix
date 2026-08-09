_: {
  flake.nixosModules.openbaoInfra =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.infra.openbao;
    in
    {
      options.services.infra.openbao = {
        enable = lib.mkEnableOption "infra OpenBao secrets engine";

        listenAddress = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1:8200";
        };

        unsealKeyFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "agenix-mounted unseal key for auto-unseal (optional).";
        };

        bootstrapScript = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = null;
          description = "One-shot KV/policy bootstrap script path.";
        };
      };

      config = lib.mkIf cfg.enable {
        services.openbao = {
          enable = true;
          package = pkgs.openbao;
          settings = {
            ui = true;
            disable_mlock = true;
            listener.default = {
              type = "tcp";
              address = cfg.listenAddress;
              tls_disable = 1;
            };
            storage.file = {
              path = "/var/lib/private/openbao/data";
            };
            api_addr = "http://${cfg.listenAddress}";
            cluster_addr = "http://127.0.0.1:8201";
          };
        };

        networking.firewall.interfaces."tailscale0".allowedTCPPorts = lib.mkAfter [ 8200 ];

        systemd.services.openbao-bootstrap = lib.mkIf (cfg.bootstrapScript != null) {
          description = "OpenBao KV and policy bootstrap";
          after = [ "openbao.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = cfg.bootstrapScript;
          };
        };
      };
    };
}
