{
  lib,
  config,
  pkgs,
  ...
}:
let
  skel = ../../../assets/kali/skel;

  # Home-manager fragment applied to every HM user when host.kali.enable.
  # Materializes Kali's /etc/skel dotfiles and overrides mime defaults to
  # the apps Kali actually ships (thunar, mousepad, parole, ristretto).
  kaliHomeModule = { lib, ... }: {
    home.file = {
      ".bashrc".source = "${skel}/bashrc";
      ".bash_logout".source = "${skel}/bash_logout";
      ".zshrc".source = "${skel}/zshrc";
      ".zprofile".source = "${skel}/zprofile";
      ".face".source = "${skel}/face";
      ".face.icon".source = "${skel}/face";
    };

    xdg.mimeApps.defaultApplications = lib.mkForce {
      "inode/directory" = [ "thunar.desktop" ];
      "text/plain" = [ "mousepad.desktop" ];
      "text/html" = [ "firefox.desktop" ];
      "x-scheme-handler/http" = [ "firefox.desktop" ];
      "x-scheme-handler/https" = [ "firefox.desktop" ];
      "x-scheme-handler/about" = [ "firefox.desktop" ];
      "x-scheme-handler/unknown" = [ "firefox.desktop" ];
      "image/png" = [ "org.xfce.ristretto.desktop" ];
      "image/jpeg" = [ "org.xfce.ristretto.desktop" ];
      "image/gif" = [ "org.xfce.ristretto.desktop" ];
      "image/webp" = [ "org.xfce.ristretto.desktop" ];
      "image/bmp" = [ "org.xfce.ristretto.desktop" ];
      "image/tiff" = [ "org.xfce.ristretto.desktop" ];
      "video/mp4" = [ "parole.desktop" ];
      "video/webm" = [ "parole.desktop" ];
      "video/x-matroska" = [ "parole.desktop" ];
      "audio/mpeg" = [ "parole.desktop" ];
      "audio/ogg" = [ "parole.desktop" ];
      "application/zip" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-tar" = [ "org.gnome.FileRoller.desktop" ];
      "application/gzip" = [ "org.gnome.FileRoller.desktop" ];
      "application/x-7z-compressed" = [ "org.gnome.FileRoller.desktop" ];
    };
  };
in
{
  config = lib.mkIf config.host.kali.enable {
    home-manager.sharedModules = [ kaliHomeModule ];

    # Ensure the apps the mime list points at are installed. zsh on the system
    # so the kali user's .zshrc is actually loadable.
    environment.systemPackages = with pkgs; [
      xfce.thunar
      xfce.mousepad
      xfce.ristretto
      xfce.parole
      file-roller
      zsh
    ];

    programs.zsh.enable = true;
  };
}
