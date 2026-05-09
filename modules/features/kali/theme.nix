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

  wallpaper = "${kali-artifacts}/share/backgrounds/kali/kali-cubes-16x9.jpg";

  desktopXml = pkgs.writeText "xfce4-desktop.xml" ''
    <?xml version="1.0" encoding="UTF-8"?>
    <channel name="xfce4-desktop" version="1.0">
      <property name="backdrop" type="empty">
        <property name="screen0" type="empty">
          <property name="monitorVirtual-1" type="empty">
            <property name="workspace0" type="empty">
              <property name="last-image" type="string" value="${wallpaper}"/>
              <property name="image-style" type="int" value="5"/>
            </property>
          </property>
          <property name="monitor0" type="empty">
            <property name="workspace0" type="empty">
              <property name="last-image" type="string" value="${wallpaper}"/>
              <property name="image-style" type="int" value="5"/>
            </property>
          </property>
        </property>
      </property>
    </channel>
  '';
in
{
  config = lib.mkIf config.host.kali.enable {
  environment.systemPackages = with pkgs; [
    kali-artifacts
    flat-remix-icon-theme
    xfce.xfce4-genmon-plugin
    xfce.xfce4-notifyd
    xfce.xfce4-power-manager
    xfce.xfce4-pulseaudio-plugin
    xfce.xfce4-cpugraph-plugin
    xfce.xfce4-whiskermenu-plugin
    ghostty
    xfce.xfce4-terminal
  ];

  environment.etc = lib.mkMerge [
    {
      "xdg/xfce4/panel/default.xml".source = "${assets}/xdg/xfce4/panel/default.xml";
      "xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml".source = desktopXml;
      "xdg/xfce4/terminal/terminalrc".source = "${assets}/xdg/xfce4/terminal/terminalrc";
      "xdg/xfce4/helpers.rc".text = ''
        WebBrowser=firefox
        FileManager=thunar
        TerminalEmulator=ghostty
      '';
      "xdg/xfce4/helpers/ghostty.desktop".text = ''
        [Desktop Entry]
        Version=1.0
        Type=X-XFCE-Helper
        X-XFCE-Category=TerminalEmulator
        X-XFCE-CommandsWithParameter=ghostty -e "%s"
        X-XFCE-Commands=ghostty
        Name=Ghostty
        Icon=utilities-terminal
      '';
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
