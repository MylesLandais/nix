{
  lib,
  config,
  pkgs,
  ...
}:
let
  assets = ../../../assets/kali;

  kali-artifacts = pkgs.runCommandLocal "kali-artifacts" { } ''
    mkdir -p $out/share/themes $out/share/backgrounds $out/share/applications $out/share/desktop-base
    cp -r ${assets}/themes/Kali-Dark $out/share/themes/
    cp -r ${assets}/backgrounds/kali $out/share/backgrounds/
    cp -r ${assets}/desktop-base/kali-theme $out/share/desktop-base/
    cp ${assets}/applications/*.desktop $out/share/applications/
  '';

  xfconfXmlDir = "${assets}/xdg/xfce4/xfconf/xfce-perchannel-xml";
in
{
  config = lib.mkIf config.host.kali.enable {
  environment.systemPackages = [
    kali-artifacts
    pkgs.flat-remix-icon-theme
  ];

  environment.etc = lib.mkMerge [
    {
      "xdg/xfce4/panel/default.xml".source = "${assets}/xdg/xfce4/panel/default.xml";
      "xdg/xfce4/terminal/terminalrc".source = "${assets}/xdg/xfce4/terminal/terminalrc";
      "xdg/xfce4/helpers.rc".source = "${assets}/xdg/xfce4/helpers.rc";
    }
    (lib.listToAttrs (
      map
        (name: {
          name = "xdg/xfce4/xfconf/xfce-perchannel-xml/${name}";
          value.source = "${xfconfXmlDir}/${name}";
        })
        [
          "xsettings.xml"
          "xfwm4.xml"
          "xfce4-desktop.xml"
          "xfce4-session.xml"
          "xfce4-power-manager.xml"
          "xfce4-screensaver.xml"
          "xfce4-keyboard-shortcuts.xml"
          "thunar.xml"
          "thunar-volman.xml"
        ]
    ))
  ];

  fonts.packages = with pkgs; [
    cantarell-fonts
    fira-code
  ];
  };
}
