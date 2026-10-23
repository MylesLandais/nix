# ~/.hermes/config.yaml is shared between Nix and hermes itself. Activation deep-
# merges the `settings` block below into the file on disk: the keys declared here
# replace the keys on disk, and every other key is left alone. The file stays a
# real writable file and not a store symlink, because hermes saves to it at
# runtime. So `settings` is authoritative for what it names and nothing else —
# an earlier comment here claimed config.yaml could not be managed from Nix,
# which stopped being true once the module grew the merge script.
#
# Secrets must NOT go in `settings`: it renders to a world-readable file in the
# Nix store. They belong in ~/.hermes/.env (mode 0600), which activation leaves
# untouched as long as `environment` and `environmentFiles` are both empty.
#
# This is a Home Manager module, not a NixOS one. The NixOS module runs hermes as
# a dedicated system user with HERMES_HOME=/var/lib/hermes/.hermes, which is a
# different state directory from the ~/.hermes that the desktop app and the CLI
# use — so the dashboard showed an empty session list while 1479 sessions sat in
# the user's home. Hermes is an agent for one person: the credentials, memory,
# sessions and cron jobs all belong to that person. The user-level module runs
# everything as warby against ~/.hermes, so every front end shares one store.
{ lib, ... }:

{
  # Upstream hermes-agent blocks saving provider API keys to ~/.hermes/.env via the
  # desktop UI / CLI whenever ~/.hermes/.managed is set to "home-manager".
  # Since Nix deliberately leaves secrets to ~/.hermes/.env (see lines 9-11),
  # ensure ~/.hermes/.managed is set to "false" after hermesAgentSetup and override
  # HERMES_MANAGED so that the desktop UI and runtime can persist credentials.
  home.activation.hermesUnmanageMarker = lib.hm.dag.entryAfter [ "hermesAgentSetup" ] ''
    echo "false" > "$HOME/.hermes/.managed"
  '';

  systemd.user.services.hermes-agent.Service.Environment = [ "HERMES_MANAGED=false" ];
  systemd.user.services.hermes-backend.Service.Environment = [ "HERMES_MANAGED=false" ];

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
      # Bind the MagicDNS name, not the 100.x address. The dashboard refuses any
      # request whose Host header differs from the address it bound to, as a
      # defence against DNS rebinding, so binding the IP would 400 every request
      # that arrives by name.
      #
      # Binding anything other than loopback also engages the authentication
      # gate, and hermes refuses to start when no auth provider is registered.
      # The credentials live in ~/.hermes/.env, not here.
      host = "cerberus.cerberus-bonito.ts.net";
      # A systemd *user* unit cannot order itself after the system
      # tailscaled.service — After= and Requires= are silent no-ops across that
      # boundary — so the name may not resolve yet at login. Poll for it.
      waitFor = "hostname";
      port = 9119;
    };

    settings = {
      model = {
        # Repointed from opencode-go to commandcode 2026-10-09: the operator's
        # OpenCode Go subscription lapsed (HTTP 403 "active OpenCode Go
        # subscription is required"), while commandcode was already set up as
        # its replacement (COMMANDCODE_API_KEY in ~/.hermes/.env, credential
        # pool in auth.json). Because this settings block deep-merges over
        # ~/.hermes/config.yaml on every activation, leaving opencode-go here
        # silently reverted the operator's config on each rebuild — the Oct 9
        # regression. Verified 2026-10-09 via live catalog probe + end-to-end
        # `hermes chat` (provider=commandcode, 200).
        # NOTE: z-ai/glm-5.3-flash rejects response_format json_schema (HTTP
        # 400, "Supported formats: json_object") and hermes' structured-output
        # retry does not classify that wording, so title generation 400s every
        # call. Workaround lives OUTSIDE this block (so activation never
        # overwrites it): auxiliary.title_generation pinned to openrouter
        # google/gemini-2.5-flash-lite in ~/.hermes/config.yaml.
        default = "z-ai/glm-5.3-flash";
        provider = "commandcode";
        base_url = "https://api.commandcode.ai/provider/v1";
        api_mode = "chat_completions";
      };
      terminal.backend = "local";
      toolsets = [ "all" ];

      # Goal judge: with no override it inherits the main runtime model.
      # Goal judge pinned to a strong reasoning model: per operator 2026-09-13,
      # the judge should reason about ambiguous completion, not just check boxes.
      # 2026-10-09: repointed alongside the model block — opencode-go is dead
      # (lapsed subscription, HTTP 403) and the pin was silently failing every
      # cron job ("HTTP 429: Go usage limit exceeded"). moonshotai/Kimi-K3 on
      # commandcode verified live 2026-10-09 (judge-shaped JSON prompt, 200).
      # History: gpt-5.6-luna on opencode-go 500'd deterministically at the
      # relay (every call, verified across repeated probes) — same-provider
      # transient retries exhausted, no fallback predicate matched a bare 500
      # (auth/payment/429/400 don't apply), so the judge fail-opened to
      # "continue" every time. kimi-k3 (Go's unqualified id) replaced it, then
      # the whole provider was dropped 2026-10-09.
      auxiliary.goal_judge.provider = "commandcode";
      auxiliary.goal_judge.model = "moonshotai/Kimi-K3";
      auxiliary.goal_judge.timeout = 120;

      # The dashboard refuses any request whose Host header is not the exact
      # address it bound to, so the tailnet IP alone would 400 even though it
      # routes fine. public_url is the one supported way to trust a second
      # hostname: urlparse().hostname is taken from it (the port is stripped)
      # and added to the accepted set, so both the MagicDNS name and the raw
      # 100.x address work. Only ONE extra host can be declared this way.
      #
      # This value is snapshotted once at startup — the request middleware
      # never re-reads config — so changing it needs a service restart, not
      # just an activation.
      dashboard.public_url = "http://100.112.41.69:9119";

      # The Petdex mascot sits in its own layout row above the prompt, but the
      # /model picker and command palette size their scroll viewport as if only
      # the input and status bar were below them (reserved_below = 6 in
      # _compute_model_picker_viewport). On Ghostty the Kitty-graphics sprite
      # takes ~10 more rows, so long lists lose their tail and bottom border.
      # Still unfixed on upstream main as of v2026.9.24; re-enable once the
      # viewport subtracts _pet_widget_height().
      display.pet.enabled = false;
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
