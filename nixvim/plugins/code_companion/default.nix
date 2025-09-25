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
                      local function read_file(path)
                      local file = io.open(path, "r")
                      if not file then return nil end
                      local content = file:read("*a")
                      file:close()
                      return content:gsub("^%s*(.-)%s*$", "%1")
                      end
                      local key = read_file("/run/user/1000/agenix/ollama")
                    return require('codecompanion.adapters').extend('ollama', {
                        env = {
                            url = "https://ollama.com";
                            api_key = key;
                        },
                        headers = { 
                          ["Content-Type"] = "application/json",
                          ["Authorization"] = "Bearer " .. key,
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
