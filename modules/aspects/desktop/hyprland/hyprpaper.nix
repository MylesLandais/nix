{ lib, ... }:
{
  flake.modules.homeManager.hyprland = lib.mkOrder 1070 {
    imports = [
      (
        {
          lib,
          config,
          osConfig,
          pkgs,
          ...
        }:
        {
          options = {
            my.hyprpaper.enable = lib.mkEnableOption "Enable hyprpaper module";
          };
          config = lib.mkIf config.my.hyprpaper.enable {
            services.hyprpaper = {
              enable = true;
              package = pkgs.hyprpaper;
              settings = {
                ipc = "on";
                splash = false;
                preload = [ osConfig.host.wallpaper ];
                wallpaper = [
                  "${osConfig.host.mainMonitor.name},${osConfig.host.wallpaper}"
                  "${osConfig.host.secondaryMonitor.name},${osConfig.host.wallpaper}"
                ];
              };
            };
          };
        }
      )
    ];
  };
}
