{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.host.desktop == "xfce") {
    services.xserver = {
      enable = true;
      desktopManager.xfce = {
        enable = true;
        enableScreensaver = false;
      };
    };

    environment.systemPackages = with pkgs; [
      xfce.xfce4-whiskermenu-plugin
      xfce.thunar-archive-plugin
      xfce.thunar-volman
      arc-theme
      papirus-icon-theme
    ];

    services.gvfs.enable = true;
    services.tumbler.enable = true;
  };
}
