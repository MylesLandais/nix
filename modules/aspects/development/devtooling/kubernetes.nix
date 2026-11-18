{ lib, ... }:
{
  flake.modules.homeManager.devtooling = lib.mkOrder 1080 {
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
            my.kubernetes.enable = lib.mkEnableOption "Enable kubernetes option";
          };
          config = lib.mkIf config.my.kubernetes.enable {
            home.packages = with pkgs; [
              kubectl
            ];
            programs.k9s = {
              enable = true;
            };
          };
        }
      )
    ];
  };
}
