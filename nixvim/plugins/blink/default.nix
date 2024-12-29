{config,lib, ...}:
{
  options = {
    blink.enable = lib.mkEnableOption "Enable blink nixvim plugin module";
  };

  config = lib.mkIf config.blink.enable {
  programs.nixvim.plugins.blink-cmp = {
    enable = true;
      settings = {
        appearance = {
           use_nvim_cmp_as_default = true;
        };
        accept = {
          auto_brackets = {
            enable = true;
          };
        };
        windows.documentation = {
          auto_show = false;
        };
        keymap = {
          preset = "default";
        };
        trigger = {
          signature_help = {
            enabled = true;
          };
        };
      };
  };
 };
}
