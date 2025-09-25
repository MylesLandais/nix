{
  config,
  lib,
  ...
}:
{
  options = {
    avante.enable = lib.mkEnableOption "Enable blink nixvim plugin module";
  };

  config = lib.mkIf config.avante.enable {
    programs.nixvim.plugins.avante = {
      enable = true;
      settings = {
        diff = {
          autojump = true;
          debug = false;
          list_opener = "copen";
        };
        highlights = {
          diff = {
            current = "DiffText";
            incoming = "DiffAdd";
          };
        };
        mappings = {
          diff = {
            both = "cb";
            next = "]x";
            none = "c0";
            ours = "co";
            prev = "[x";
            theirs = "ct";
          };
        };
        provider = "ollama";
        providers = {
          gemini = {
            model = "gemini-2.5-flash";
          };
          ollama = {
            endpoint = "https://ollama.com";
            model = "qwen3-coder:480b";
            api_key_name = "OLLAMA_API_KEY";
          };
          lmstudio = {
            __inherited_from = "openai";
            endpoint = "http://127.0.0.1:1234/v1";
            model = "qwen/qwen3-coder-30b";
            timeout = 30000;
            temperature = 0;
            max_completion_tokens = 8192;
          };
        };
      };
    };
  };
}
