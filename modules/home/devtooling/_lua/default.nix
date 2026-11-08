{
  pkgs,
  lib,
  config,
  ...
}:
{
  options = {
    my.lua.enable = lib.mkEnableOption "Enable lua module";
  };
  config = lib.mkIf config.my.lua.enable {
    home.packages = with pkgs; [
      lua-language-server
    ];
  };
}
