_: {
  flake.modules.nixos.scbw =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.host.scbw;
      packageGroups = import ../_features/scbw/packages.nix { inherit pkgs; };

      prefixYaml = builtins.toJSON cfg.prefixDir;
      battleNetConfigYaml = builtins.toJSON "${cfg.prefixDir}/drive_c/users/$USER/AppData/Roaming/Battle.net/Battle.net.config";

      # Local copy of the Lutris Battle.net recipe. Lutris still presents its
      # own destination confirmation, but Battle.net installs quietly and the
      # prefix/product launch stay stable across community catalog changes.
      bootstrapInstaller = pkgs.writeText "starcraft-remastered-bootstrap.yml" ''
        name: "StarCraft: Remastered"
        game_slug: starcraft-remastered
        version: "NixOS Battle.net"
        slug: starcraft-remastered-nixos
        runner: wine
        script:
          files:
          - setup:
              filename: Battle.net-Setup.exe
              url: https://www.battle.net/download/getInstallerForGame?os=win&version=LIVE&gameProgram=BATTLENET_APP
          game:
            arch: win64
            args: '--exec="launch S1"'
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
                Sign in and install StarCraft: Remastered on the next launch.
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
      registerInstaller = pkgs.writeText "starcraft-remastered-register.yml" ''
        name: "StarCraft: Remastered"
        game_slug: starcraft-remastered
        version: "NixOS Battle.net"
        slug: starcraft-remastered-nixos
        runner: wine
        script:
          game:
            arch: win64
            args: '--exec="launch S1"'
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

      starcraftRemasteredApp = pkgs.writeShellApplication {
        name = "starcraft-remastered";
        runtimeInputs = with pkgs; [
          coreutils
          findutils
          gamemode
          lutris
        ];
        text = ''
          prefix_dir=${lib.escapeShellArg cfg.prefixDir}
          lutris_games_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/lutris/games"
          legacy_lutris_games_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/lutris/games"

          usage() {
            cat <<'EOF'
          Usage: starcraft-remastered [install|play|status|debug|help]

            install  bootstrap Battle.net or register the configured shared prefix
            play     launch StarCraft: Remastered through Lutris and GameMode
            status   report Battle.net prefix and Lutris registration state
            debug    launch StarCraft: Remastered with Lutris debug logging

          With no command, the launcher installs/registers when needed, then plays.
          The command is also available as: scbw
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
                  -iname '*starcraft*remastered*.yml' -print -quit 2>/dev/null || true)
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
              echo "StarCraft: Remastered is already registered: $registration"
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

          play_game() {
            if ! registration_file >/dev/null; then
              echo "StarCraft: Remastered is not registered; run: starcraft-remastered install" >&2
              return 1
            fi
            exec gamemoderun lutris lutris:rungame/starcraft-remastered
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
                play_game
              else
                install_game
              fi
              ;;
            install) install_game ;;
            play) play_game ;;
            status) show_status ;;
            debug)
              if ! registration_file >/dev/null; then
                echo "StarCraft: Remastered is not registered; run: starcraft-remastered install" >&2
                exit 1
              fi
              exec gamemoderun lutris --debug lutris:rungame/starcraft-remastered
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

      starcraftRemastered = pkgs.symlinkJoin {
        name = "starcraft-remastered-tools";
        paths = [ starcraftRemasteredApp ];
        postBuild = ''
          ln -s starcraft-remastered "$out/bin/scbw"
        '';
        meta.mainProgram = "starcraft-remastered";
      };

      starcraftRemasteredDesktop = pkgs.makeDesktopItem {
        name = "starcraft-remastered";
        desktopName = "StarCraft: Remastered";
        genericName = "Real-Time Strategy Game";
        comment = "Install or launch StarCraft: Remastered through Battle.net";
        exec = "${starcraftRemastered}/bin/starcraft-remastered";
        icon = "applications-games";
        terminal = false;
        categories = [
          "Game"
          "StrategyGame"
        ];
        keywords = [
          "StarCraft"
          "Brood War"
          "Battle.net"
        ];
        startupWMClass = "StarCraft.exe";
      };
    in
    {
      options.host.scbw = {
        enable = lib.mkEnableOption "StarCraft: Remastered through Battle.net and Lutris";

        prefixDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/warby/Games/battlenet";
          description = "Mutable shared Battle.net Wine prefix used by Lutris.";
        };

        botDev.enable = lib.mkEnableOption "classic Brood War 1.16.1 OpenBW/BWAPI build tooling";
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = lib.hasPrefix "/" cfg.prefixDir;
            message = "host.scbw.prefixDir must be an absolute path";
          }
        ];

        nixpkgs.config.allowUnfree = true;

        environment.systemPackages =
          packageGroups.runtime
          ++ [
            starcraftRemastered
            starcraftRemasteredDesktop
          ]
          ++ lib.optionals cfg.botDev.enable packageGroups.botDev;
      };
    };
}
