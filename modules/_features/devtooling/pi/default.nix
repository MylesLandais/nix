# pi coding agent (badlogic/pi-mono), packaged by llm-agents.nix.
#
# Provider wiring mirrors Hermes: OpenCode Go (opencode-go) behind
# https://opencode.ai/zen/go/v1, model glm-5.3-flash, chat-completions API.
#
# No API key lives in this repo or in ~/.pi. The `pi` wrapper resolves
# OPENCODE_GO_API_KEY from the keyring through secretspec at start-up; pi's
# models.json interpolates it as $OPENCODE_GO_API_KEY. One-time setup:
#
#   SECRETSPEC_FILE=~/.config/pi/secretspec.toml \
#     secretspec set OPENCODE_GO_API_KEY -p keyring -P default
#
# ~/.pi is mutable state (settings, sessions, models-store): only the parts we
# own are managed — the wrapper and the secretspec manifest. models.json is
# seeded by the wrapper when absent so pi's own edits never get overwritten.
{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
let
  llm = inputs.llm.packages.${pkgs.system};
  inherit (llm) pi;

  secretspecFile = "${config.home.homeDirectory}/.config/pi/secretspec.toml";
  modelsJson = "${config.home.homeDirectory}/.pi/agent/models.json";
  sessionFile = "${config.home.homeDirectory}/.pi/agent/opencode-session";

  # OpenCode Go routes requests with session affinity via x-opencode-session.
  # pi must NOT reuse Hermes' session id, so the wrapper seeds a stable
  # per-user id (rotate with: pi-session-rotate) that models.json reads via
  # pi's !command value resolution.
  piSession = pkgs.writeShellApplication {
    name = "pi-session-rotate";
    runtimeInputs = [ pkgs.util-linux ];
    text = ''
      mkdir -p "$(dirname "${sessionFile}")"
      uuidgen > "${sessionFile}"
      cat "${sessionFile}"
    '';
  };

  # Launch pi with secrets injected from the keyring. secretspec fails loudly
  # when a required secret is missing, so pi never starts keyless.
  piWrapped = pkgs.writeShellApplication {
    name = "pi";
    runtimeInputs = [
      pkgs.secretspec
      pkgs.util-linux
    ];
    text = ''
      export SECRETSPEC_FILE=${lib.escapeShellArg secretspecFile}

      # Seed a pi models.json with our OpenCode Go provider on first use.
      # Later edits by pi (or the user) win — this only fills an absent file.
      if [ ! -f ${modelsJson} ]; then
        mkdir -p "$(dirname "${modelsJson}")"
        if [ ! -f ${sessionFile} ]; then
          uuidgen > "${sessionFile}"
        fi
        cat > ${modelsJson} <<'EOF'
      {
        "providers": {
          "opencode-go": {
            "baseUrl": "https://opencode.ai/zen/go/v1",
            "api": "openai-completions",
            "apiKey": "$OPENCODE_GO_API_KEY",
            "headers": {
              "x-opencode-session": "!cat \"$HOME/.pi/agent/opencode-session\""
            },
            "models": [
              {
                "id": "glm-5.3-flash",
                "name": "GLM 5.3 Flash (OpenCode Go)",
                "reasoning": true,
                "input": ["text", "image"],
                "contextWindow": 200000,
                "maxTokens": 32768
              }
            ]
          }
        }
      }
      EOF
      fi

      exec secretspec run \
        --provider keyring \
        --profile default \
        --reason "pi coding agent launch" \
        -- ${lib.escapeShellArg (lib.getExe pi)} "$@"
    '';
  };
in
{
  options = {
    pi-agent.enable = lib.mkEnableOption "Enable pi coding agent module";
  };

  config = lib.mkIf config.pi-agent.enable {
    # Declarations only — no values. `secretspec set` writes those to the keyring.
    home.file.".config/pi/secretspec.toml".text = ''
      # Managed by modules/_features/devtooling/pi/default.nix.
      # Values live in the keyring, never here.
      [project]
      name = "pi-agents"
      revision = "1.0"

      [profiles.default]
      OPENCODE_GO_API_KEY = { description = "OpenCode Go subscription key", required = true }
    '';

    home.packages = [
      piWrapped
      piSession
    ];
  };
}
