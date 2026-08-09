{
  lib,
  config,
  ...
}:
{
  imports = [
    ./kitty.nix
    ./ghostty.nix
  ];

  options = {
    terminals.enable = lib.mkEnableOption "Enable terminals module";
  };
  config = lib.mkIf config.terminals.enable {
    kitty.enable = lib.mkDefault true;
    ghostty.enable = lib.mkDefault true;
  };
}
