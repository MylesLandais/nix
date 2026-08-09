{ pkgs }:

with pkgs;
[
  # ═══════════════════════════════════════════════
  # BATTLE.NET / STARCRAFT: REMASTERED (play)
  # Install Battle.net via Lutris, then SC:R from
  # the launcher. Game data stays under ~/Games.
  # ═══════════════════════════════════════════════
  lutris
  wineWow64Packages.stagingFull # Battle.net + SC:R under Wine
  winetricks
  dxvk # Vulkan translation for Wine prefixes

  # ═══════════════════════════════════════════════
  # BOT TOOLCHAIN — OpenBW / BWAPI (native Linux)
  # Clone openbw/openbw + openbw/bwapi; build with
  # cmake -DOPENBW_DIR=... -DOPENBW_ENABLE_UI=1
  # Needs Stardat.mpq Broodat.mpq Patch_rt.mpq from
  # a classic 1.16.1 install in the launch cwd.
  # ═══════════════════════════════════════════════
  cmake
  ninja
  gnumake
  pkg-config
  gcc
  SDL2
  zlib

  # ═══════════════════════════════════════════════
  # BOT TOOLCHAIN — Wine + MinGW (STARTcraft-style)
  # Cross-compile Windows BWAPI bots, run under Wine
  # against classic StarCraft.exe / injector setups.
  # ═══════════════════════════════════════════════
  pkgsCross.mingwW64.buildPackages.gcc
]
