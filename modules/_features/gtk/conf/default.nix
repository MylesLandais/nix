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
      # gtk.theme and gtk4.theme are both owned by stylix (stylix.targets.gtk.enable).
      # It generates the widget theme from the Kanagawa base16Scheme, replacing
      # pkgs.kanagawa-gtk-theme which nixpkgs removed along with its GTK2
      # gtk-engine-murrine dependency. Setting either here collides with stylix.
      # host.themeData.gtk.name ("Kanagawa-B") is now unused for the widget theme;
      # iconName above is still live.

      # stylix names the theme "adw-gtk3" — the light variant — and relies on the
      # prefer-dark flag for polarity, which it does not itself write into
      # settings.ini. The old Kanagawa-B theme was inherently dark so never needed
      # it. Without this, GTK3 renders light, and Chromium-based browsers (Helium,
      # Vivaldi, Chromium) read the GTK theme to pick their own light/dark mode —
      # so they flip to light too. dconf already carries color-scheme=prefer-dark;
      # this is the GTK3-side equivalent.
      gtk3.extraConfig."gtk-application-prefer-dark-theme" = 1;
      gtk4.extraConfig."gtk-application-prefer-dark-theme" = 1;
    };

    # GTK file manager: Nemo + archive integration
    # Qt-based systems use Dolphin instead; this block is GTK-only.
    home.packages = with pkgs; [
      nemo # Cinnamon file manager (GTK, works great standalone under Hyprland)
      nemo-fileroller # Nemo → "Open with Archive Manager" context menu bridge
      file-roller # GNOME Archive Manager (backend for nemo-fileroller)
      evince # GNOME document viewer (PDF, ePub, etc.)
      pkgs.gnome.gvfs # SMB/network locations for Nemo (matches services.gvfs on Cerberus)

      # Qt icon theme fallback: Papirus-Dark has complete freedesktop coverage.
      # The GTK icon theme (Kanagawa) inherits Yaru/gnome which are not installed,
      # so Qt apps that call QIcon::fromTheme fall through to hicolor and miss icons
      # like system-file-manager, showing a checkerboard in noctalia. Papirus-Dark
      # (Inherits=breeze,hicolor — both installed) fills that gap without changing
      # the GTK visual theme.
      papirus-icon-theme
    ];

    # XDG MIME associations for GTK-mode desktop.
    # Explicitly setting inode/directory is required because kitty registers itself
    # for it via kitty-open.desktop (installed by the terminals module), which would
    # otherwise win over nemo in the default lookup order.
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "inode/directory" = [ "nemo.desktop" ];
        "application/pdf" = [ "org.gnome.Evince.desktop" ];
        "application/epub+zip" = [ "com.github.johnfactotum.Foliate.desktop" ];
        "image/png" = [
          "org.gnome.eog.desktop"
          "ristretto.desktop"
        ];
        "image/jpeg" = [
          "org.gnome.eog.desktop"
          "ristretto.desktop"
        ];
        "image/gif" = [
          "org.gnome.eog.desktop"
          "ristretto.desktop"
        ];
        "image/webp" = [
          "org.gnome.eog.desktop"
          "ristretto.desktop"
        ];
        "image/avif" = [
          "org.gnome.eog.desktop"
          "ristretto.desktop"
        ];
        "image/bmp" = [
          "org.gnome.eog.desktop"
          "ristretto.desktop"
        ];
        "image/tiff" = [
          "org.gnome.eog.desktop"
          "ristretto.desktop"
        ];
        "video/mp4" = [ "mpv.desktop" ];
        "video/mpeg" = [ "mpv.desktop" ];
        "video/webm" = [ "mpv.desktop" ];
        "video/x-matroska" = [ "mpv.desktop" ];
        "video/quicktime" = [ "mpv.desktop" ];
        "audio/mpeg" = [ "mpv.desktop" ];
        "audio/mp4" = [ "mpv.desktop" ];
        "audio/aac" = [ "mpv.desktop" ];
        "audio/wav" = [ "mpv.desktop" ];
        "audio/flac" = [ "mpv.desktop" ];
        "audio/ogg" = [ "mpv.desktop" ];
        "text/html" = [ "firefox.desktop" ];
        "x-scheme-handler/http" = [ "firefox.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" ];
      };
    };

    # Qt6 apps (Wireshark, etc.): platform theme and palette come from stylix
    # (targets.qt + Kvantum Base16). Papirus-Dark icons via stylix.icons.dark.

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

    # Quickshell/Noctalia use QIcon::fromTheme (not gtk-icon-theme dconf alone).
    # Match stylix.icons.dark so launcher entries like nemo (Icon=system-file-manager) resolve.
    home.sessionVariables.QT_ICON_THEME = "Papirus-Dark";

    # Prefer the app-specific icon name; more reliable than system-file-manager in Qt lookup.
    xdg.desktopEntries.nemo = {
      name = "Files";
      comment = "Access and organize files";
      exec = "nemo %U";
      icon = "nemo";
      terminal = false;
      categories = [
        "GNOME"
        "GTK"
        "Utility"
        "Core"
      ];
      mimeType = [
        "inode/directory"
        "application/x-gnome-saved-search"
      ];
    };

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
