_final: prev: {
  code-cursor = prev.appimageTools.wrapType2 rec {
    pname = "code-cursor";
    version = "3.13.10";
    src = prev.fetchurl {
      url = "https://downloads.cursor.com/production/4f02290ccd9304f0e6bf8ee85f6e9106f02ac1f7/linux/x64/Cursor-${version}-x86_64.AppImage";
      hash = "sha256-pZq2rQnIbFLejOkK2y0GZEVRmuNKZvI+oxaviK/vpXQ=";
    };
    extraInstallCommands = ''
      mv $out/bin/${pname} $out/bin/cursor 2>/dev/null || true
    '';
  };
}
