{ lib, ... }:
{
  flake.modules.homeManager.devtooling = lib.mkOrder 1110 {
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
            my.remmina.enable = lib.mkEnableOption "Remmina remote desktop client (VNC, RDP, SSH)";
          };

          config = lib.mkIf config.my.remmina.enable {
            home.packages = with pkgs; [
              remmina
            ];
          };
        }
      )
    ];
  };
}
