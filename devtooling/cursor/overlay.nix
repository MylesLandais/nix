final: prev: {
  code-cursor = prev.appimageTools.wrapType2 rec {
    pname = "code-cursor";
    version = "3.9.16";
    src = prev.fetchurl {
      url = "https://downloads.cursor.com/production/042b3c1a4c53f2c3808067f519fbfc67b72cad8b/linux/x64/Cursor-${version}-x86_64.AppImage";
      hash = "sha256-dG61VYGMHPip57ldzNICEi1yPc4s1dON+MlDGiKadKc=";
    };
    extraInstallCommands = ''
      mv $out/bin/${pname} $out/bin/cursor 2>/dev/null || true
    '';
  };
}
