{
  bar,
  lib,
  wallpaper,
}:
{
  exec-once = [
    "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP"
    "add_record_player"
    "wl-paste --watch cliphist store &"
  ];
}
