_: {
  flake.modules.homeManager.terminals =
    {
      lib,
      config,
      ...
    }:
    {
      imports = [
        ./_kitty.nix
        ./_ghostty.nix
      ];

      options = {
        my.terminals.enable = lib.mkEnableOption "Enable terminals module";
      };
      config = lib.mkIf config.my.terminals.enable {
        my.kitty.enable = lib.mkDefault true;
        my.ghostty.enable = lib.mkDefault true;
      };
    };
}
