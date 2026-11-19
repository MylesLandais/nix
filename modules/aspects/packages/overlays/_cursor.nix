# Private helper: the Cursor package overlay imported by Cerberus.
_final: prev:
let
  pname = "code-cursor";
  version = "3.30.14";
  src = prev.fetchurl {
    url = "https://downloads.cursor.com/production/5f54c8173e5552412beb40702adac16275677fa0/linux/x64/Cursor-${version}-x86_64.AppImage";
    hash = "sha256-6gfkPW9kEnXIhd4LqzZXVBEMVyH+hSTNuDtoUIDoq7k=";
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
