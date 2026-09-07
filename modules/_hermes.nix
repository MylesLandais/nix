# TODO(unsolved): ~/.hermes/config.yaml is NOT managed by Nix. It is a live user
# file that hermes reads directly and it takes precedence over any settings defined
# in the services.hermes-agent.settings block below. Changes made here (model,
# terminal.backend, etc.) may be silently ignored if config.yaml defines the same
# keys. There is currently no mechanism to manage config.yaml via home.file or
# similar because the hermes module does not expose a way to disable its own
# config generation. Until resolved, treat config.yaml as the source of truth for
# runtime settings and keep this block as documentation only.
{
  lib,
  ...
}:

{
  # The hermes-agent flake's nixosModule sets HERMES_HOME=/var/lib/hermes/.hermes
  # system-wide, which leaks into interactive shells and makes the user-facing
  # `hermes` CLI try to read /var/lib/hermes/.hermes/.env (no read permission for
  # the warby user). Override so interactive use points at the user-owned dir.
  environment.variables.HERMES_HOME = lib.mkForce "/home/warby/.hermes";

  # The upstream module defaults to Restart="always" and exposes no start limit, so
  # a gateway that cannot start has nothing stopping it. On the v2026.6.19 pin it
  # crash-looped 12557 times at ~5s CPU per attempt. Cap it: five failures in five
  # minutes and it stays failed, visible in `systemctl --failed`, instead of looping.
  systemd.services.hermes-agent = {
    startLimitIntervalSec = 300;
    startLimitBurst = 5;
  };

  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;

    # The browser admin panel. `serve` and `dashboard` are the same entry point
    # with one flag of difference; only `dashboard` serves the web application,
    # so `serve` answers 404 on every path but /docs. Keep host on loopback:
    # any other address turns on the dashboard authentication gate, which needs
    # credentials configured before a client can connect at all.
    backend = {
      mode = "dashboard";
      host = "127.0.0.1";
      port = 9119;
    };

    settings = {
      model = {
        # Not every opencode-go model works through hermes. Verified 2026-09-07:
        #   OK      deepseek-*, glm-*, hy*, kimi-*, longcat-2.0, mimo-*, omen-alpha
        #   500     muse-spark-1.2/1.3-contributor, gpt-5.6-luna (relay-side)
        #   401     grok-4.6 ("not supported for format oa-compat")
        #   broken  minimax-*, qwen* — these work at the relay over
        #           chat_completions, but runtime_provider.py hard-overrides
        #           api_mode for opencode providers and forces them onto
        #           anthropic_messages, whose client never merges the
        #           x-opencode-session header below. Not fixable from config.
        default = "glm-5";
        provider = "opencode-go";
        base_url = "https://opencode.ai/zen/go/v1";
        api_mode = "chat_completions";
        # The OpenCode Go relay rejects requests without x-opencode-session
        # (HTTP 400, "cannot be routed efficiently"). hermes-agent 0.20.0 never
        # emits it, so inject it here. Regenerate the uuid freely; the relay
        # only needs a stable opaque id per client.
        default_headers = {
          "x-opencode-session" = "ae72de72-ea03-48eb-bce1-bd8a802e5afa";
        };
      };
      terminal.backend = "local";
      toolsets = [ "all" ];
    };

    # SOUL.md must live in hermesHomeFiles, not documents: hermes reads it from
    # HERMES_HOME. Since v2026.8.31 `documents` also asserts an explicit
    # workingDirectory, which this module does not set.
    hermesHomeFiles = {
      "SOUL.md" = ''
        You are Hermes, an AI agent on a NixOS workstation named Cerberus.
        You have local terminal access. Be concise and direct.
      '';
    };
  };
}
