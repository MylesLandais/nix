{
  lib,
  config,
  osConfig,
  pkgs,
  ...
}:
# TODO: build out a kali.nix module that packages kali-themes,
# kali-wallpapers, and kali-menu (none of these are in nixpkgs today)
# and import it here to replace the Arc-Dark + kanagawa-dragon stand-in
# below with the real Kali artifacts.
{
  options = {
    xfce.enable = lib.mkEnableOption "Enable xfce module (legacy X11 fallback)";
  };

  config = lib.mkIf (config.xfce.enable && osConfig.host.desktop == "xfce") {
    home.packages = with pkgs; [
      arc-theme
      papirus-icon-theme
      xfce4-whiskermenu-plugin
      xfce4-pulseaudio-plugin
      xfce4-systemload-plugin
      xfce4-cpugraph-plugin
    ];

    xfconf.settings = {
      xsettings = {
        "Net/ThemeName" = "Arc-Dark";
        "Net/IconThemeName" = "Papirus-Dark";
        "Gtk/CursorThemeName" = "Adwaita";
      };
      xfwm4 = {
        "general/theme" = "Arc-Dark";
        "general/title_font" = "Sans Bold 10";
        "general/button_layout" = "O|SHMC";
        "general/workspace_count" = 4;
      };
      xfce4-desktop = {
        "backdrop/screen0/monitor0/workspace0/last-image" =
          toString osConfig.host.wallpaper;
        "backdrop/screen0/monitor0/workspace0/image-style" = 5;
      };
    };
  };
}
