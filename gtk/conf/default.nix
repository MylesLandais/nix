{
  pkgs,
  lib,
  config,
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
        name = "Kanagawa";
      };
      #theme = {
      #name = "Kanagawa-B";
      #package = pkgs.tokyonight-gtk-theme;
      #package = pkgs.kanagawa-gtk-theme;
      #:};
    };
  };
}
