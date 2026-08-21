# DeepSeek Harness (`dsh`) — agent harness web UI.
#
# Points at the local llama-swap endpoint (modules/services/vllm.nix) rather than
# DeepSeek's hosted API, so the models under test are driven through the same
# agent loop they would be in production.
#
# The harness is an OpenAI-compatible client, so switching which model it drives
# is a matter of the `model` name it sends — llama-swap does the load/unload. No
# configuration here changes when you switch models.
_: {
  flake.nixosModules.deepseekHarnessInfra =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.services.infra.deepseek-harness;
    in
    {
      options.services.infra.deepseek-harness = {
        enable = lib.mkEnableOption "DeepSeek Harness (dsh) web UI";

        port = lib.mkOption {
          type = lib.types.port;
          default = 3080;
          description = "Loopback port for the dsh web UI. Matches upstream's default.";
        };

        envFile = lib.mkOption {
          type = lib.types.nullOr lib.types.path;
          default = "/etc/deepseek-harness/env";
          description = ''
            systemd EnvironmentFile supplying DEEPSEEK_API_KEY (and any other
            real provider keys). Must live outside the Nix store, which is
            world-readable. Loaded with a leading "-" so a missing file leaves the
            unit startable instead of wedging boot.

            Not required for the local setup — baseUrl below already points the
            harness at the router. This is for real provider keys.
          '';
        };

        baseUrl = lib.mkOption {
          type = lib.types.str;
          default = "http://127.0.0.1:8000/v1";
          description = ''
            OpenAI-compatible endpoint the harness drives — by default the local
            llama-swap router (services.infra.llmRouter), exported as
            DEEPSEEK_BASE_URL. Not a secret, so it is set here rather than in
            envFile; envFile still wins, since systemd applies EnvironmentFile
            after Environment.

            Note the harness needs a large context: its system prompt plus tool
            definitions measured 10,280 tokens before the first user message, so
            any model it drives must be served with at least ~16K context.
          '';
        };

        package = lib.mkOption {
          type = lib.types.package;
          default = pkgs.deepseek-harness;
          defaultText = lib.literalExpression "pkgs.deepseek-harness";
          description = "Package providing bin/dsh.";
        };
      };

      config = lib.mkIf cfg.enable {
        systemd.services.deepseek-harness = {
          description = "DeepSeek Harness (dsh) web UI";
          after = [
            "network-online.target"
            "llama-swap.service"
          ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];

          # Repo-wide convention: bound restart loops rather than letting a
          # failing unit spin (see valkey.nix / pyload.nix).
          startLimitIntervalSec = 300;
          startLimitBurst = 5;

          environment = {
            # Upstream binds 127.0.0.1 by default; pin it explicitly so an
            # upstream default change cannot quietly expose the agent UI, which
            # has filesystem and shell tools attached to it.
            HOST = "127.0.0.1";
            NODE_ENV = "production";
            # dsh does NOT read OPENAI_BASE_URL. Its bundled provider is
            # @deepseek-ai/dsh-llm-deepseek, which resolves its endpoint from
            # DEEPSEEK_BASE_URL and posts to "''${baseURL}/chat/completions" —
            # a plain OpenAI-shaped call, so any OpenAI-compatible server works,
            # but only under these variable names.
            DEEPSEEK_BASE_URL = cfg.baseUrl;
            # llama-server requires the Authorization header to be present but
            # does not validate it unless started with --api-key, so a
            # placeholder makes the harness work out of the box. Override in
            # envFile to point at the real DeepSeek API.
            DEEPSEEK_API_KEY = "local";
          };

          serviceConfig = {
            ExecStart = "${cfg.package}/bin/dsh web --port ${toString cfg.port}";
            EnvironmentFile = lib.mkIf (cfg.envFile != null) [ "-${cfg.envFile}" ];

            Restart = "on-failure";
            RestartSec = "5s";

            DynamicUser = true;
            StateDirectory = "deepseek-harness";
            ProtectSystem = "strict";
            ProtectHome = true;
            NoNewPrivileges = true;
            PrivateTmp = true;
            RestrictAddressFamilies = [
              "AF_INET"
              "AF_INET6"
            ];
          };
        };
      };
    };
}
