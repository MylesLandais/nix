{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    zed.enable = lib.mkEnableOption "Enable zed module";
  };
  config = lib.mkIf config.zed.enable {
    home.packages = with pkgs; [
      nil
    ];

    programs.zed-editor = {
      enable = true;
      userSettings = {
        theme = "Kanagawa Wave";
        buffer_font_family = "Maple Mono NF";
        ui_font_size = 16;
        buffer_font_size = 14;
        autosave = "on_focus_change";
        vim_mode = false;
        languages = {
          "Nix" = {
            language_servers = [ "nil" ];
          };
        };
        lsp = {
          nix = {
            binary = {
              path = "${pkgs.nil}/bin/nil";
            };
          };
        };
        language_models = {
          openai_compatible = {
            "glm" = {
              api_url = "https://api.z.ai/api/coding/paas/v4";
              available_models = [
                {
                  name = "glm-4.7";
                  max_tokens = 200000;
                  max_output_tokens = 32000;
                  max_completion_tokens = 200000;
                  capabilities = {
                    tools = true;
                    images = true;
                    parallel_tool_calls = true;
                    prompt_cache_key = true;
                  };
                }
              ];
            };
            "ZAI" = {
              api_url = "https://api.z.ai/api/paas/v4";
              available_models = [
                {
                  name = "glm-4.7";
                  display_name = "GLM-4.7 (Z.ai)";
                  max_tokens = 200000;
                  capabilities = {
                    tools = true;
                    images = true;
                    parallel_tool_calls = true;
                    prompt_cache_key = true;
                  };
                }
              ];
            };
          };
        };
        terminal = {
          alternate_scroll = "off";
          blinking = "off";
          copy_on_select = false;
          dock = "bottom";
          detect_venv = {
            on = {
              directories = [
                ".env"
                "env"
                ".venv"
                "venv"
              ];
              activate_script = "default";
            };
          };
          env = {
            TERM = "ghostty";
          };
          font_family = "Hack Nerd Font";
          font_features = null;
          font_size = null;
          line_height = "comfortable";
          option_as_meta = false;
          button = false;
          shell = "system";
          toolbar = {
            title = true;
          };
          working_directory = "current_project_directory";
        };
        agent_servers = {
          "hermes" = {
            type = "custom";
            command = "hermes";
            args = [ "acp" ];
            env = {};
          };
          "Opencode" = {
            type = "custom";
            command = "opencode";
            args = [ "acp" ];
            env = {};
          };
          "pi" = {
            type = "custom";
            command = "npx";
            args = [ "-y" "pi-acp" ];
            env = {};
          };
        };
      };
    };
  };
}
