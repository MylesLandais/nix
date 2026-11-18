{ lib, ... }:
{
  flake.modules.homeManager.shelltools = lib.mkOrder 1070 {
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
            my.direnv.enable = lib.mkEnableOption "Enable direnv module";
          };

          config = lib.mkIf config.my.direnv.enable {
            programs.direnv = {
              enable = true;
              package = pkgs.direnv;
            };
          };
        }
      )
    ];
  };
}
