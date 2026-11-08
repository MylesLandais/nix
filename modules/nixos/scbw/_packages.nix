{ pkgs }:

{
  runtime = with pkgs; [
    # Battle.net / StarCraft: Remastered runtime and installer support.
    cabextract
    curl
    dxvk
    gamemode
    lutris
    p7zip
    unzip
    wineWow64Packages.stagingFull
    winetricks
  ];

  # Classic Brood War 1.16.1 bot development is deliberately separate from
  # Remastered: BWAPI cannot inject into the modern Battle.net build.
  botDev = with pkgs; [
    # OpenBW / BWAPI native Linux toolchain.
    cmake
    ninja
    gnumake
    pkg-config
    gcc
    SDL2
    zlib

    # STARTcraft-style Windows bot cross-compilation.
    pkgsCross.mingwW64.buildPackages.gcc
  ];
}
