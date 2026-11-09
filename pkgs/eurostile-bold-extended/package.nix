{ stdenvNoCC, ... }:

stdenvNoCC.mkDerivation {
  pname = "eurostile-bold-extended";
  version = "1.0";

  src = ../../assets/fonts/eurostile-bold-extended;

  dontUnpack = true;

  installPhase = ''
    install -Dm444 $src/eurostile-bold-extended.otf $out/share/fonts/opentype/eurostile-bold-extended.otf
  '';

  meta = {
    description = "Eurostile Bold Extended font, sourced from wdbm/style";
    # license unknown/unverified upstream
  };
}
