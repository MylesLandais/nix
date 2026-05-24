{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}:
{
  options = {
    gtk-conf.enable = lib.mkEnableOption "Enable gtk module";
  };

  config = lib.mkIf config.gtk-conf.enable {
    gtk = {
      enable = true;
      iconTheme = {
        package = pkgs.kanagawa-icon-theme;
        name = osConfig.host.themeData.gtk.iconName;
      };
      theme = {
        inherit (osConfig.host.themeData.gtk) name;
        package = pkgs.kanagawa-gtk-theme;
      };
      gtk4.theme = config.gtk.theme;
    };

    # GTK file manager: Nemo + archive integration
    # Qt-based systems use Dolphin instead; this block is GTK-only.
    home.packages = with pkgs; [
      nemo           # Cinnamon file manager (GTK, works great standalone under Hyprland)
      nemo-fileroller # Nemo → "Open with Archive Manager" context menu bridge
      file-roller     # GNOME Archive Manager (backend for nemo-fileroller)
    ];

    # Open Ghostty terminal from inside Nemo (right-click → "Open in Ghostty")
    home.file.".local/share/nemo/actions/open-ghostty.nemo_action".text = ''
      [Nemo Action]
      Active=true
      Name=Open in Ghostty
      Comment=Open Ghostty terminal in the current directory
      Exec=${pkgs.ghostty}/bin/ghostty --working-directory=%F
      Icon-Name=com.mitchellh.ghostty
      Selection=any
      Extensions=dir;
      Quote=double
    '';

    dconf.settings = {
      # Dark mode signal for portals (Firefox, Chrome, GTK4 apps)
      "org/gnome/desktop/interface".color-scheme = "prefer-dark";

      # Nemo preferences
      "org/nemo/preferences" = {
        show-image-thumbnails = "always";
        thumbnail-limit = lib.hm.gvariant.mkUint64 2147483648; # 2 GB
        context-menus-show-open-in-terminal = true;
      };

      # Cinnamon terminal wiring: Nemo uses this to launch "Open Terminal Here"
      "org/cinnamon/desktop/default-applications/terminal" = {
        exec = "${pkgs.ghostty}/bin/ghostty";
        exec-arg = "--working-directory";
      };
    };
  };
}
