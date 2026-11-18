_: {
  flake.modules.homeManager.terminals =
    {
      lib,
      config,
      ...
    }:
    {
      options = {
        my.terminals.enable = lib.mkEnableOption "Enable terminals module";
      };
      config = lib.mkIf config.my.terminals.enable {
        my.kitty.enable = lib.mkDefault true;
        my.ghostty.enable = lib.mkDefault true;
      };
    };
}
