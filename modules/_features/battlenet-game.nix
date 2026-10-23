# Builds the launcher command and desktop entry for one Battle.net game that
# lives in a shared, mutable Lutris Wine prefix. Imported by path from the
# per-game modules (modules/services/scbw.nix, modules/services/warcraft3.nix).
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
  bootstrapInstaller = pkgs.writeText "${gameSlug}-bootstrap.yml" ''
    name: ${nameYaml}
    game_slug: ${gameSlug}
    version: "NixOS Battle.net"
    slug: ${gameSlug}-nixos
    runner: wine
    script:
      files:
      - setup:
          filename: Battle.net-Setup.exe
          url: https://www.battle.net/download/getInstallerForGame?os=win&version=LIVE&gameProgram=BATTLENET_APP
      game:
        arch: win64
        args: ${argsYaml}
        exe: drive_c/Program Files (x86)/Battle.net/Battle.net.exe
        prefix: ${prefixYaml}
      installer:
      - task:
          arch: win64
          description: Creating the shared 64-bit Battle.net Wine prefix.
          name: create_prefix
          prefix: ${prefixYaml}
      - task:
          arch: win64
          description: 'Wine Staging: Enabling DXVA2'
          key: backend
          name: set_regedit
          path: HKEY_CURRENT_USER\Software\Wine\DXVA2
          prefix: ${prefixYaml}
          value: va
      - write_json:
          data:
            Client:
              GameLaunchWindowBehavior: '2'
              GameSearch:
                BackgroundSearch: 'true'
              HardwareAcceleration: 'false'
              Install:
                DownloadLimitNextPatchInBps: '0'
              Sound:
                Enabled: 'false'
              Streaming:
                StreamingEnabled: 'false'
          description: Disabling Battle.net hardware acceleration, sound, and streaming.
          file: ${battleNetConfigYaml}
      - task:
          args: --quiet
          description: |-
            Installing Battle.net quietly.
            Sign in and install ${name} on the next launch.
          executable: setup
          exclude_processes: Agent.exe "Battle.net Helper.exe" Battle.net.exe
          name: wineexec
          prefix: ${prefixYaml}
      - task:
          name: winekill
          prefix: ${prefixYaml}
      system:
        env:
          DXVK_STATE_CACHE_PATH: ${prefixYaml}
          STAGING_SHARED_MEMORY: 1
          __GL_SHADER_DISK_CACHE: 1
          __GL_SHADER_DISK_CACHE_PATH: ${prefixYaml}
          __GL_SHADER_DISK_CACHE_SKIP_CLEANUP: 1
        exclude_processes: Agent.exe "Battle.net Helper.exe"
      wine:
        battleye: false
        eac: false
        fsr: false
        overrides:
          locationapi: d
  '';

  # Register a Battle.net prefix that was installed before this module
  # without modifying or reinstalling anything inside it.
  registerInstaller = pkgs.writeText "${gameSlug}-register.yml" ''
    name: ${nameYaml}
    game_slug: ${gameSlug}
    version: "NixOS Battle.net"
    slug: ${gameSlug}-nixos
    runner: wine
    script:
      game:
        arch: win64
        args: ${argsYaml}
        exe: drive_c/Program Files (x86)/Battle.net/Battle.net.exe
        prefix: ${prefixYaml}
      installer: []
      system:
        env:
          DXVK_STATE_CACHE_PATH: ${prefixYaml}
          STAGING_SHARED_MEMORY: 1
          __GL_SHADER_DISK_CACHE: 1
          __GL_SHADER_DISK_CACHE_PATH: ${prefixYaml}
          __GL_SHADER_DISK_CACHE_SKIP_CLEANUP: 1
      wine:
        battleye: false
        eac: false
        fsr: false
  '';

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
    text = ''
      prefix_dir=${lib.escapeShellArg prefixDir}
      game_name=${lib.escapeShellArg name}
      lutris_games_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/lutris/games"
      legacy_lutris_games_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/lutris/games"

      usage() {
        cat <<'EOF'
      Usage: ${command} [install|play|status|debug|help]

        install  bootstrap Battle.net or register the configured shared prefix
        play     launch ${name} through Lutris and GameMode
        status   report Battle.net prefix and Lutris registration state
        debug    launch ${name} with Lutris debug logging

      With no command, the launcher installs/registers when needed, then plays.
      ${aliasNote}
      EOF
      }

      battle_net_exe() {
        for candidate in \
          "$prefix_dir/drive_c/Program Files (x86)/Battle.net/Battle.net.exe" \
          "$prefix_dir/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe"
        do
          if [ -f "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
          fi
        done
        return 1
      }

      registration_file() {
        for games_dir in "$lutris_games_dir" "$legacy_lutris_games_dir"; do
          if [ -d "$games_dir" ]; then
            registration=$(find "$games_dir" -maxdepth 1 -type f \
              -iname ${lib.escapeShellArg registrationGlob} -print -quit 2>/dev/null || true)
            if [ -n "$registration" ]; then
              printf '%s\n' "$registration"
              return 0
            fi
          fi
        done
        return 1
      }

      install_game() {
        if registration=$(registration_file); then
          echo "$game_name is already registered: $registration"
          return 0
        fi

        mkdir -p -- "$(dirname "$prefix_dir")"
        if client=$(battle_net_exe); then
          echo "Registering the existing Battle.net client: $client"
          exec lutris -i ${registerInstaller}
        fi

        if [ -d "$prefix_dir" ]; then
          echo "Reusing the existing partial prefix without deleting it: $prefix_dir"
        else
          echo "Creating the shared Battle.net prefix: $prefix_dir"
        fi
        exec lutris -i ${bootstrapInstaller}
      }

      require_registration() {
        if ! registration_file >/dev/null; then
          echo "$game_name is not registered; run: ${command} install" >&2
          exit 1
        fi
      }

      show_status() {
        failed=0
        echo "prefix: $prefix_dir"
        if client=$(battle_net_exe); then
          echo "Battle.net: present ($client)"
        else
          echo "Battle.net: missing"
          failed=1
        fi
        if registration=$(registration_file); then
          echo "Lutris entry: present ($registration)"
        else
          echo "Lutris entry: missing"
          failed=1
        fi
        return "$failed"
      }

      action="''${1:-open}"
      case "$action" in
        open)
          if registration_file >/dev/null; then
            exec gamemoderun lutris lutris:rungame/${gameSlug}
          else
            install_game
          fi
          ;;
        install) install_game ;;
        play)
          require_registration
          exec gamemoderun lutris lutris:rungame/${gameSlug}
          ;;
        status) show_status ;;
        debug)
          require_registration
          exec gamemoderun lutris --debug lutris:rungame/${gameSlug}
          ;;
        help|-h|--help) usage ;;
        *)
          echo "Unknown command: $action" >&2
          usage >&2
          exit 2
          ;;
      esac
    '';
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
