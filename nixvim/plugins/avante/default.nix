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
            endpoint = "http://127.0.0.1:11434";
            model = "gemma3:12b";
          };
        };
      };
    };
  };
}
