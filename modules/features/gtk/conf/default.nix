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
      evince          # GNOME document viewer (PDF, ePub, etc.)

      # Qt icon theme fallback: Papirus-Dark has complete freedesktop coverage.
      # The GTK icon theme (Kanagawa) inherits Yaru/gnome which are not installed,
      # so Qt apps that call QIcon::fromTheme fall through to hicolor and miss icons
      # like system-file-manager, showing a checkerboard in noctalia. Papirus-Dark
      # (Inherits=breeze,hicolor — both installed) fills that gap without changing
      # the GTK visual theme.
      papirus-icon-theme
      qt6Packages.qt6ct # Qt6 theme configurator; reads ~/.config/qt6ct/qt6ct.conf
    ];

    # XDG MIME associations for GTK-mode desktop.
    # Explicitly setting inode/directory is required because kitty registers itself
    # for it via kitty-open.desktop (installed by the terminals module), which would
    # otherwise win over nemo in the default lookup order.
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "inode/directory"         = [ "nemo.desktop" ];
        "application/pdf"         = [ "org.gnome.Evince.desktop" ];
        "application/epub+zip"    = [ "org.gnome.Evince.desktop" ];
        "image/png"               = [ "org.gnome.eog.desktop" "ristretto.desktop" ];
        "image/jpeg"              = [ "org.gnome.eog.desktop" "ristretto.desktop" ];
        "image/gif"               = [ "org.gnome.eog.desktop" "ristretto.desktop" ];
        "image/webp"              = [ "org.gnome.eog.desktop" "ristretto.desktop" ];
        "image/avif"              = [ "org.gnome.eog.desktop" "ristretto.desktop" ];
        "image/bmp"               = [ "org.gnome.eog.desktop" "ristretto.desktop" ];
        "image/tiff"              = [ "org.gnome.eog.desktop" "ristretto.desktop" ];
        "video/mp4"               = [ "mpv.desktop" ];
        "video/mpeg"              = [ "mpv.desktop" ];
        "video/webm"              = [ "mpv.desktop" ];
        "video/x-matroska"        = [ "mpv.desktop" ];
        "video/quicktime"         = [ "mpv.desktop" ];
        "audio/mpeg"              = [ "mpv.desktop" ];
        "audio/mp4"               = [ "mpv.desktop" ];
        "audio/aac"               = [ "mpv.desktop" ];
        "audio/wav"               = [ "mpv.desktop" ];
        "audio/flac"              = [ "mpv.desktop" ];
        "audio/ogg"               = [ "mpv.desktop" ];
        "text/html"               = [ "firefox.desktop" ];
        "x-scheme-handler/http"   = [ "firefox.desktop" ];
        "x-scheme-handler/https"  = [ "firefox.desktop" ];
      };
    };

    # Point Qt6 apps (Quickshell/noctalia) at qt6ct so they use Papirus-Dark
    # for icon lookup instead of inheriting the broken Kanagawa→Yaru chain.
    home.sessionVariables.QT_QPA_PLATFORMTHEME = lib.mkDefault "qt6ct";

    xdg.configFile."qt6ct/qt6ct.conf".text = ''
      [Appearance]
      icon_theme=Papirus-Dark
      style=Fusion
    '';

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
