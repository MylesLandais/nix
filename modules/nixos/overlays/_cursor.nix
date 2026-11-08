_final: prev:
let
  pname = "code-cursor";
  version = "3.20.17";
  src = prev.fetchurl {
    url = "https://downloads.cursor.com/production/0c32194e3fb5ffaced9fb36430b860ec301e1fc8/linux/x64/Cursor-${version}-x86_64.AppImage";
    hash = "sha256-E+gInIUlGhAveZBa3/uR3SmN1YYmUlmb5jRX4o3DEhg=";
  };
  contents = prev.appimageTools.extract { inherit pname version src; };
in
{
  code-cursor = prev.appimageTools.wrapType2 {
    inherit pname version src;
    # native-keymap dlopens libxkbfile; the default AppImage FHS environment
    # includes X11 but not this library, so keyboard layout detection fails.
    extraPkgs = pkgs: [ pkgs.libxkbfile ];
    # Same icon path as nixpkgs' code-cursor (share/pixmaps/cursor.png), so
    # app-wrappers.nix can install it into hicolor on any host.
    extraInstallCommands = ''
      mv $out/bin/${pname} $out/bin/cursor 2>/dev/null || true
      install -Dm444 ${contents}/co.anysphere.cursor.png $out/share/pixmaps/cursor.png
    '';
  };
}
