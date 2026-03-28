{
  lib,
  config,
  osConfig,
  pkgs,
  ...
}:
{
  options = {
    hyprpaper.enable = lib.mkEnableOption "Enable hyprpaper module";
  };
  config = lib.mkIf config.hyprpaper.enable {
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
