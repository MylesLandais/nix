_final: prev: {
  code-cursor = prev.appimageTools.wrapType2 rec {
    pname = "code-cursor";
    version = "3.20.17";
    src = prev.fetchurl {
      url = "https://downloads.cursor.com/production/0c32194e3fb5ffaced9fb36430b860ec301e1fc8/linux/x64/Cursor-${version}-x86_64.AppImage";
      hash = "sha256-E+gInIUlGhAveZBa3/uR3SmN1YYmUlmb5jRX4o3DEhg=";
    };
    # native-keymap dlopens libxkbfile; the default AppImage FHS environment
    # includes X11 but not this library, so keyboard layout detection fails.
    extraPkgs = pkgs: [ pkgs.libxkbfile ];
    extraInstallCommands = ''
      mv $out/bin/${pname} $out/bin/cursor 2>/dev/null || true
    '';
  };
}
