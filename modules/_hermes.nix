# TODO(unsolved): ~/.hermes/config.yaml is NOT managed by Nix. It is a live user
# file that hermes reads directly and it takes precedence over any settings defined
# in the services.hermes-agent.settings block below. Changes made here (model,
# terminal.backend, etc.) may be silently ignored if config.yaml defines the same
# keys. There is currently no mechanism to manage config.yaml via home.file or
# similar because the hermes module does not expose a way to disable its own
# config generation. Until resolved, treat config.yaml as the source of truth for
# runtime settings and keep this block as documentation only.
#
# This is a Home Manager module, not a NixOS one. The NixOS module runs hermes as
# a dedicated system user with HERMES_HOME=/var/lib/hermes/.hermes, which is a
# different state directory from the ~/.hermes that the desktop app and the CLI
# use — so the dashboard showed an empty session list while 1479 sessions sat in
# the user's home. Hermes is an agent for one person: the credentials, memory,
# sessions and cron jobs all belong to that person. The user-level module runs
# everything as warby against ~/.hermes, so every front end shares one store.
_:

{
  programs.hermes-agent = {
    # Replaces the NixOS module's addToSystemPackages. Also exports
    # HERMES_HOME, which is why the old environment.variables mkForce
    # override is gone: hermesHome already defaults to ~/.hermes.
    enable = true;
  };

  # The upstream module defaults to Restart="always" and exposes no start limit, so
  # a gateway that cannot start has nothing stopping it. On the v2026.6.19 pin it
  # crash-looped 12557 times at ~5s CPU per attempt. Cap it: five failures in five
  # minutes and it stays failed, visible in `systemctl --user --failed`, instead of
  # looping.
  systemd.user.services.hermes-agent.Unit = {
    StartLimitIntervalSec = 300;
    StartLimitBurst = 5;
  };

  services.hermes-agent = {
    enable = true;

    # Not enabled by default on this module, unlike the NixOS one. Without it
    # the messaging gateway (Telegram, Discord, Slack) does not run at all.
    gateway.enable = true;

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
