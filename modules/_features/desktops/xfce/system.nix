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
      xfce4-whiskermenu-plugin
      thunar-archive-plugin
      thunar-volman
      # arc-theme removed from nixpkgs (GTK2 gtk-engine-murrine). XFCE falls back to
      # Adwaita; this is the legacy X11 fallback desktop, not the daily driver.
      papirus-icon-theme
    ];

    services.gvfs.enable = true;
    services.tumbler.enable = true;
  };
}
