{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf (config.host.desktop == "hyprland") {
    services.xserver.enable = true;
    services.xserver.xkb = {
      layout = "us";
      variant = "";
    };

    programs.hyprland.enable = true;

    # The hyprland package ships a uwsm-managed session entry alongside the plain
    # one, and programs.hyprland registers both regardless of withUWSM. uwsm is not
    # enabled here, so picking that entry dies at login (wayland-session-bindpid@
    # does not exist). Pin the session that works.
    services.displayManager.defaultSession = "hyprland";

    # greetd / tuigreet owned by nixosModules.greeter (host.greeter)

    xdg.portal = {
      enable = true;
      extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];
      config = {
        common.default = [
          "hyprland"
          "gtk"
        ];
        hyprland."org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
    };

    # Exports Wayland env vars to user systemd units
    systemd.user.services.hyprland-session = {
      description = "Hyprland Wayland Session";
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = "yes";
        ExecStart = "${pkgs.systemd}/bin/systemctl --user import-environment DISPLAY WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE XDG_CURRENT_DESKTOP";
      };
    };
  };
}
