{
  lib,
  config,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.host.desktop == "niri") {
    environment.systemPackages = with pkgs; [
      niri
      xwayland-satellite
      swaybg
      fuzzel
    ];

    services.displayManager.sessionPackages = [ pkgs.niri ];

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    security.polkit.enable = true;
    services.dbus.enable = true;
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
    };
  };
}
