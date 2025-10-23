{
  lib,
  self,
  config,
  options,
  ...
}:
let
  ollama_key_path = config.age.secrets.ollama.path;
in
{
  options = {
    companion.enable = lib.mkEnableOption "Enable code companion nixvim plugin module";
  };
  config = lib.mkIf config.cmp.enable {
    programs.nixvim = {
      plugins = {
        codecompanion = {
          enable = true;
          lazyLoad.enable = false;
          settings = {
            adapters = {
              ollama = {
                __raw = ''
                  function()
                    return require('codecompanion.adapters').extend('ollama', {
                        env = {
                            url = "https://ollama.com";
                            api_key = builtins.readFile ollama_key_path;
                        },
                        headers = { 
                          ["Content-Type"] = "application/json",
                          ["Authorization"] = "Bearer " .. builtins.readFile ollama_key_path,
                        },
                        schema = {
                            model = {
                                default = 'qwen3-coder:480b',
                            },
                            num_ctx = {
                                default = 32768,
                            },
                        },
                    })
                  end
                '';
              };

            };
            opts = {
              log_level = "DEBUG";
              send_code = true;
              use_default_actions = true;
              use_default_prompts = true;
            };
            strategies = {
              agent = {
                adapter = "ollama";
              };
              chat = {
                adapter = "ollama";
              };
              inline = {
                adapter = "ollama";
              };
            };
          };
        };
      };
    };
  };
}
