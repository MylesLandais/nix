# Builds the launcher command and desktop entry for one Battle.net game that
# lives in a shared, mutable Lutris Wine prefix. Imported by path from the
# per-game modules (currently nixos.scbw, modules/nixos/scbw/; WC3 runs through umu
# directly in modules/services/warcraft3.nix).
#
# The first run installs Battle.net quietly into the prefix (or registers an
# existing prefix with Lutris without touching it); later runs launch the game
# through Battle.net's `--exec="launch <code>"`. Signing in and the one-time
# in-client game download stay manual: Blizzard's login can't be automated.
{ pkgs, lib }:
{
  name,
  gameSlug,
  launchCode,
  command,
  prefixDir,
  registrationGlob,
  aliases ? [ ],
  comment,
  keywords ? [ ],
  startupWMClass,
}:
let
  prefixYaml = builtins.toJSON prefixDir;
  battleNetConfigYaml = builtins.toJSON "${prefixDir}/drive_c/users/$USER/AppData/Roaming/Battle.net/Battle.net.config";
  nameYaml = builtins.toJSON name;
  argsYaml = "'--exec=\"launch ${launchCode}\"'";

  # Local copy of the Lutris Battle.net recipe. Lutris still presents its
  # own destination confirmation, but Battle.net installs quietly and the
  # prefix/product launch stay stable across community catalog changes.
  bootstrapInstaller = pkgs.writeText "${gameSlug}-bootstrap.yml" (
    builtins.replaceStrings
      [
        "@NIX1@"
        "@NIX2@"
        "@NIX3@"
        "@NIX4@"
        "@NIX5@"
        "@NIX6@"
        "@NIX7@"
        "@NIX8@"
        "@NIX9@"
        "@NIX10@"
        "@NIX11@"
        "@NIX12@"
        "@NIX13@"
      ]
      [
        "${nameYaml}"
        "${gameSlug}"
        "${gameSlug}"
        "${argsYaml}"
        "${prefixYaml}"
        "${prefixYaml}"
        "${prefixYaml}"
        "${battleNetConfigYaml}"
        "${name}"
        "${prefixYaml}"
        "${prefixYaml}"
        "${prefixYaml}"
        "${prefixYaml}"
      ]
      (builtins.readFile ./battlenet-bootstrap.yml)
  );

  # Register a Battle.net prefix that was installed before this module
  # without modifying or reinstalling anything inside it.
  registerInstaller = pkgs.writeText "${gameSlug}-register.yml" (
    builtins.replaceStrings
      [
        "@NIX1@"
        "@NIX2@"
        "@NIX3@"
        "@NIX4@"
        "@NIX5@"
        "@NIX6@"
        "@NIX7@"
      ]
      [
        "${nameYaml}"
        "${gameSlug}"
        "${gameSlug}"
        "${argsYaml}"
        "${prefixYaml}"
        "${prefixYaml}"
        "${prefixYaml}"
      ]
      (builtins.readFile ./battlenet-register.yml)
  );

  aliasNote = lib.optionalString (
    aliases != [ ]
  ) "The command is also available as: ${lib.concatStringsSep ", " aliases}";

  app = pkgs.writeShellApplication {
    name = command;
    runtimeInputs = with pkgs; [
      coreutils
      findutils
      gamemode
      lutris
    ];
    text = builtins.replaceStrings
        [
          "@NIX1@"
          "@NIX2@"
          "@NIX3@"
          "@NIX4@"
          "@NIX5@"
          "@NIX6@"
          "@NIX7@"
          "@NIX8@"
          "@NIX9@"
          "@NIX10@"
          "@NIX11@"
          "@NIX12@"
          "@NIX13@"
        ]
        [
          "${lib.escapeShellArg prefixDir}"
          "${lib.escapeShellArg name}"
          "${command}"
          "${name}"
          "${name}"
          "${aliasNote}"
          "${lib.escapeShellArg registrationGlob}"
          "${registerInstaller}"
          "${bootstrapInstaller}"
          "${command}"
          "${gameSlug}"
          "${gameSlug}"
          "${gameSlug}"
        ]
        (builtins.readFile ./battlenet-launcher.sh);
  };

  package = pkgs.symlinkJoin {
    name = "${command}-tools";
    paths = [ app ];
    postBuild = lib.concatMapStrings (alias: ''
      ln -s ${command} "$out/bin/${alias}"
    '') aliases;
    meta.mainProgram = command;
  };

  desktop = pkgs.makeDesktopItem {
    name = command;
    desktopName = name;
    genericName = "Real-Time Strategy Game";
    inherit comment keywords startupWMClass;
    exec = "${package}/bin/${command}";
    icon = "applications-games";
    terminal = false;
    categories = [
      "Game"
      "StrategyGame"
    ];
  };
in
{
  inherit package desktop;
}
