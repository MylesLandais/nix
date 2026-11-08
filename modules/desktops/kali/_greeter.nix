{
  lib,
  config,
  pkgs,
  ...
}:
let
  assets = ../../../assets/kali;
  loginBg = "${assets}/desktop-base/kali-theme/login/background.svg";
in
{
  config = lib.mkIf config.host.kali.enable {
    services.greetd.enable = lib.mkForce false;

    services.xserver.displayManager.lightdm = {
      enable = true;
      background = loginBg;
      greeters.gtk = {
        enable = true;
        theme = {
          name = "Kali-Light";
          package = pkgs.runCommandLocal "kali-light-theme" { } ''
            mkdir -p $out/share/themes
            cp -r ${assets}/themes/Kali-Light $out/share/themes/
          '';
        };
        iconTheme = {
          name = "Flat-Remix-Blue-Light";
          package = pkgs.flat-remix-icon-theme;
        };
        cursorTheme = {
          name = "Adwaita";
          package = pkgs.adwaita-icon-theme;
        };
        extraConfig = ''
          font-name = Cantarell 11
          xft-antialias = true
          xft-dpi = 96
          xft-hintstyle = slight
          xft-rgba = rgb
          indicators = ~host;~spacer;~session;~layout;~a11y;~clock;~power;
          clock-format = %d %b, %H:%M
        '';
      };
    };
  };
}
