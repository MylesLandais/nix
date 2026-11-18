{ lib, ... }:
{
  flake.modules.homeManager.devtooling = lib.mkOrder 1090 {
    imports = [
      (
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
      )
    ];
  };
}
