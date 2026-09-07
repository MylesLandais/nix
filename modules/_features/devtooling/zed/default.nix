# Zed editor, restored after the 2026-01-10 removal (d86eb3c, 6269b35).
#
# The point of this module is the ACP agent wiring. Zed's own agent registry is
# useless on NixOS: it ships codex-acp as a prebuilt glibc binary and claude-acp
# via npx, and the downloaded binaries cannot run here. Every agent below is
# therefore `type = "custom"` pointing at an absolute store path, which also
# survives being launched from Hyprland (no shell init, no PATH inheritance).
#
# Secrets: no API keys live in this file or in settings.json. The gemini and pi
# agents are launched through secretspec wrappers that resolve keys from the
# keyring at start-up. One-time setup, per key:
#
#   SECRETSPEC_FILE=~/.config/zed/secretspec.toml \
#     secretspec set GEMINI_API_KEY -p keyring -P pi
#   SECRETSPEC_FILE=~/.config/zed/secretspec.toml \
#     secretspec set OPENROUTER_API_KEY -p keyring -P pi
#
# settings.json is mutable (mutableUserSettings): home-manager deep-merges the
# values below into the live file on every activation, so Zed's UI can still
# save settings while Nix stays authoritative for the keys it declares.
{
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
let
  llm = inputs.llm.packages.${pkgs.system};

  secretspecFile = "${config.home.homeDirectory}/.config/zed/secretspec.toml";

  # Launch an agent with secrets injected from the keyring. secretspec fails
  # loudly when a required secret is missing, so the agent never starts keyless.
  withSecrets =
    name: exe: args:
    lib.getExe (
      pkgs.writeShellApplication {
        name = "zed-${name}-acp";
        runtimeInputs = [ pkgs.secretspec ];
        text = ''
          export SECRETSPEC_FILE=${lib.escapeShellArg secretspecFile}
          exec secretspec run \
            --provider keyring \
            --profile ${name} \
            --reason "zed acp agent: ${name}" \
            -- ${lib.escapeShellArg exe} ${lib.escapeShellArgs args}
        '';
      }
    );
in
{
  options = {
    zed.enable = lib.mkEnableOption "Enable zed module";
  };

  config = lib.mkIf config.zed.enable {
    # Declarations only — no values. `secretspec set` writes those to the keyring.
    home.file.".config/zed/secretspec.toml".text = ''
      # Managed by modules/_features/devtooling/zed/default.nix.
      # Values live in the keyring, never here. See the module header.
      [project]
      name = "zed-agents"
      revision = "1.0"

      # One profile per agent, so each wrapper only demands the keys it needs.
      # `default` must declare at least one secret, so it mirrors gemini.
      [profiles.default]
      GEMINI_API_KEY = { description = "Google AI Studio key", required = true }

      [profiles.gemini]
      GEMINI_API_KEY = { description = "Google AI Studio key", required = true }

      [profiles.pi]
      GEMINI_API_KEY = { description = "Google AI Studio key", required = true }
      OPENROUTER_API_KEY = { description = "OpenRouter key", required = true }

      [profiles.hermes]
      OPENCODE_GO_API_KEY = { description = "OpenCode Go subscription key", required = true }
    '';

    programs.zed-editor = {
      enable = true;
      # Zed rewrites settings.json whenever a setting is changed in the UI; a
      # store symlink makes it error instead. Merge rather than own.
      mutableUserSettings = true;

      extensions = [
        "nix"
        "toml"
      ];

      # Language servers Zed shells out to. Keeps the absolute store path that
      # used to be hardcoded under lsp.nix.binary.path out of settings.json.
      extraPackages = [ pkgs.nil ];

      userSettings = {
        theme = "Kanagawa Wave";
        buffer_font_family = "Maple Mono NF";
        buffer_font_size = 14;
        ui_font_size = 16;
        autosave = "on_focus_change";
        vim_mode = true;

        languages.Nix.language_servers = [ "nil" ];

        agent = {
          tool_permissions.default = "allow";
          default_model = {
            provider = "google";
            model = "gemini-3-flash-preview";
          };
          model_parameters = [ ];
        };

        language_models.openai_compatible = {
          glm = {
            api_url = "https://api.z.ai/api/coding/paas/v4";
            available_models = [
              {
                name = "glm-4.7";
                max_tokens = 200000;
                max_output_tokens = 32000;
                max_completion_tokens = 200000;
                capabilities = {
                  images = true;
                  parallel_tool_calls = true;
                  prompt_cache_key = true;
                  tools = true;
                };
              }
            ];
          };
          ZAI = {
            api_url = "https://api.z.ai/api/paas/v4";
            available_models = [
              {
                name = "glm-4.7";
                display_name = "GLM-4.7 (Z.ai)";
                max_tokens = 200000;
                capabilities = {
                  images = true;
                  parallel_tool_calls = true;
                  prompt_cache_key = true;
                  tools = true;
                };
              }
            ];
          };
        };

        agent_servers = {
          # Anthropic's ACP adapter; drives the `claude` CLI from _packages.nix.
          claude = {
            type = "custom";
            command = lib.getExe llm.claude-agent-acp;
            args = [ ];
            env = { };
          };

          # Wraps the patched codex from modules/_home.nix. Must come from the
          # llm input: nixpkgs still has codex-acp 0.13.0, whose bundled config
          # parser rejects `service_tier` in ~/.codex/config.toml.
          codex = {
            type = "custom";
            command = lib.getExe llm.codex-acp;
            args = [ ];
            env = { };
          };

          hermes = {
            type = "custom";
            command = "${inputs.hermes-agent.packages.${pkgs.system}.default}/bin/hermes";
            args = [ "acp" ];
            env = { };
          };

          # Must stay custom: the registry download is a glibc build that cannot
          # execute on NixOS.
          opencode = {
            type = "custom";
            command = lib.getExe llm.opencode;
            args = [ "acp" ];
            env = { };
          };

          gemini = {
            type = "custom";
            command = withSecrets "gemini" (lib.getExe llm.gemini-cli) [ "--acp" ];
            args = [ ];
            env = { };
          };

          # pi-acp is a separate npm package with no Nix packaging yet, so this
          # one entry still resolves through npx at launch.
          pi = {
            type = "custom";
            command = withSecrets "pi" "${pkgs.nodejs}/bin/npx" [
              "-y"
              "pi-acp"
            ];
            args = [ ];
            env = { };
          };
        };

        terminal = {
          alternate_scroll = "off";
          blinking = "off";
          button = false;
          copy_on_select = false;
          detect_venv.on = {
            activate_script = "default";
            directories = [
              ".env"
              "env"
              ".venv"
              "venv"
            ];
          };
          dock = "bottom";
          env.TERM = "ghostty";
          font_family = "Hack Nerd Font";
          font_features = null;
          font_size = null;
          line_height = "comfortable";
          option_as_meta = false;
          shell = "system";
          toolbar.title = true;
          working_directory = "current_project_directory";
        };
      };
    };
  };
}
