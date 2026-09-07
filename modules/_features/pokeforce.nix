{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.host.pokeforce;

  launcherArchive = pkgs.fetchurl {
    url = "https://cdn.pokeforce.org/launcher/PokeForce%20Launcher%20Linux.tar";
    hash = "sha256-yXZ9RgkIkkWn4nWtZGI7s6qATJsuNmXrfAsDOKX7/F8=";
  };

  launcherAppImage = pkgs.runCommand "pokeforce-launcher.AppImage" { } ''
    tar -xf ${launcherArchive}
    install -Dm755 "PokeForce Launcher.AppImage" "$out"
  '';

  pokeforce = pkgs.appimageTools.wrapType2 {
    pname = "pokeforce";
    version = "beta-2026-09-04";
    src = launcherAppImage;

    extraInstallCommands = ''
      install -Dm644 ${pkgs.appimageTools.extractType2 { pname = "pokeforce-extracted"; version = "beta-2026-09-04"; src = launcherAppImage; }}/PokeForce.png \
        "$out/share/icons/hicolor/256x256/apps/pokeforce.png"

      install -Dm644 /dev/stdin "$out/share/applications/pokeforce.desktop" <<EOF
      [Desktop Entry]
      Type=Application
      Name=PokéForce
      Comment=Fan-made Pokémon MMORPG launcher
      Exec=pokeforce
      Icon=pokeforce
      Categories=Game;RolePlaying;
      Terminal=false
      StartupWMClass=game-launcher
      EOF
    '';

    extraPkgs = pkgs': with pkgs'; [
      fontconfig
      freetype
      fribidi
      harfbuzz
      libGL
      libdrm
      libgbm
      libx11
      libxcb
      stdenv.cc.cc.lib
      zlib
    ];

    meta = {
      description = "Launcher for the PokéForce fan-made Pokémon MMORPG";
      homepage = "https://pokeforce.org/";
      license = lib.licenses.unfree;
      mainProgram = "pokeforce";
      platforms = [ "x86_64-linux" ];
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    };
  };
in
{
  options.host.pokeforce.enable = lib.mkEnableOption "PokéForce launcher";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pokeforce ];
  };
}
