_: {
  flake.modules.nixos.warcraft3 =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.host.warcraft3;
      name = "Warcraft III: Reforged";

      # Launches straight through umu-run instead of Lutris: Lutris itself used
      # umu for this Proton build, so skipping it only drops the Lutris startup
      # (~7 s) and its extra bubblewrap layer. The prefix stays mutable and
      # separate from StarCraft's, because WC3 needs its own patched Proton.
      launcher = pkgs.writeShellApplication {
        name = "warcraft3-reforged";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          gamemode
          umu-launcher
        ];
        text = ''
          prefix_dir=${lib.escapeShellArg cfg.prefixDir}
          proton_path=${lib.escapeShellArg cfg.protonPath}
          launch_mode=${lib.escapeShellArg cfg.launchMode}
          game_args=(${lib.escapeShellArgs cfg.gameArgs})

          drive_c="$prefix_dir/drive_c"
          battle_net_exe="$drive_c/Program Files (x86)/Battle.net/Battle.net.exe"
          game_exe="$drive_c/Program Files (x86)/Warcraft III/_retail_/x86_64/Warcraft III.exe"
          # Proton runs everything as "steamuser"; this is the file the client reads.
          battle_net_config="$drive_c/users/steamuser/AppData/Roaming/Battle.net/Battle.net.config"

          usage() {
            cat <<'EOF'
          Usage: warcraft3-reforged [play|battlenet|direct|install|status|debug|help] [game args...]

            play       launch using the configured mode (${cfg.launchMode})
            battlenet  open Battle.net and request the W3 launch (needed for patches)
            direct     start Warcraft III.exe directly, skipping the Battle.net window
            install    install Battle.net into the prefix, then sign in and install WC3
            status     report prefix, Proton, game, and ntsync state
            debug      like play, with a Proton log written to the prefix

          With no command, the launcher installs when needed, then plays.
          The command is also available as: wc3
          EOF
          }

          use_proton() {
            if [ ! -x "$proton_path/proton" ]; then
              echo "Proton build not found: $proton_path" >&2
              exit 1
            fi
            if [ "''${DISPLAY:-}" = ":0" ] && [ ! -S /tmp/.X11-unix/X0 ]; then
              # Without the X0 socket Wine falls back to its Wayland driver,
              # where the WC3 menu renders black.
              echo "warning: /tmp/.X11-unix/X0 is missing; WC3 will likely render black" >&2
            fi
            export WINEPREFIX="$prefix_dir"
            export PROTONPATH="$proton_path"
            export GAMEID=umu-default
            # Controller-navigation helper; GE enables it by default and it
            # starts two extra .NET processes per launch.
            export PROTON_USE_XALIA=0
            # Keeps DXVK reporting the real NVIDIA adapter, as under Lutris.
            export PROTON_ENABLE_NVAPI=1
            # Skip the per-launch network check for Steam Runtime updates.
            export UMU_RUNTIME_UPDATE=0
            export WINEDLLOVERRIDES="locationapi=d''${WINEDLLOVERRIDES:+;$WINEDLLOVERRIDES}"
            export __GL_SHADER_DISK_CACHE=1
            export __GL_SHADER_DISK_CACHE_PATH="$prefix_dir"
            export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
          }

          seed_battle_net_config() {
            [ -f "$battle_net_config" ] && return 0
            mkdir -p -- "$(dirname "$battle_net_config")"
            cat >"$battle_net_config" <<'EOF'
          {
              "Client": {
                  "GameLaunchWindowBehavior": "2",
                  "HardwareAcceleration": "false",
                  "Sound": { "Enabled": "false" },
                  "Streaming": { "StreamingEnabled": "false" }
              }
          }
          EOF
          }

          run_battle_net() {
            use_proton
            exec gamemoderun umu-run "$battle_net_exe" --exec="launch W3"
          }

          run_direct() {
            if [ ! -f "$game_exe" ]; then
              echo "Warcraft III is not installed in $prefix_dir; run: warcraft3-reforged battlenet" >&2
              exit 1
            fi
            use_proton
            # The same arguments Battle.net passes when it launches the game.
            exec gamemoderun umu-run "$game_exe" -launch -uid w3 "''${game_args[@]}" "$@"
          }

          play() {
            if [ "$launch_mode" = direct ]; then
              run_direct "$@"
            else
              run_battle_net
            fi
          }

          install_battle_net() {
            if [ -f "$battle_net_exe" ]; then
              echo "Battle.net is already installed: $battle_net_exe"
              return 0
            fi
            mkdir -p -- "$prefix_dir"
            seed_battle_net_config
            setup="''${XDG_CACHE_HOME:-$HOME/.cache}/warcraft3-reforged/Battle.net-Setup.exe"
            mkdir -p -- "$(dirname "$setup")"
            curl -fL --retry 3 -o "$setup" \
              'https://www.battle.net/download/getInstallerForGame?os=win&version=LIVE&gameProgram=BATTLENET_APP'
            use_proton
            echo "Installing Battle.net. Sign in, then install ${name} from the client."
            exec gamemoderun umu-run "$setup"
          }

          show_status() {
            failed=0
            echo "prefix: $prefix_dir"
            echo "launch mode: $launch_mode"
            if [ -x "$proton_path/proton" ]; then
              echo "Proton: present ($proton_path)"
            else
              echo "Proton: missing ($proton_path)"
              failed=1
            fi
            if [ -f "$battle_net_exe" ]; then
              echo "Battle.net: present"
            else
              echo "Battle.net: missing"
              failed=1
            fi
            if [ -f "$game_exe" ]; then
              echo "Warcraft III: present"
            else
              echo "Warcraft III: missing"
              failed=1
            fi
            if [ -c /dev/ntsync ]; then
              echo "ntsync: available"
            else
              echo "ntsync: missing (Proton falls back to fsync)"
            fi
            return "$failed"
          }

          action="''${1:-open}"
          [ "$#" -gt 0 ] && shift
          case "$action" in
            open)
              if [ -f "$game_exe" ]; then
                play "$@"
              elif [ -f "$battle_net_exe" ]; then
                run_battle_net
              else
                install_battle_net
              fi
              ;;
            play) play "$@" ;;
            battlenet) run_battle_net ;;
            direct) run_direct "$@" ;;
            install) install_battle_net ;;
            status) show_status ;;
            debug)
              export PROTON_LOG=1
              export PROTON_LOG_DIR="$prefix_dir"
              echo "Proton log: $prefix_dir/steam-*.log"
              play "$@"
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
        name = "warcraft3-reforged-tools";
        paths = [ launcher ];
        postBuild = ''
          ln -s warcraft3-reforged "$out/bin/wc3"
        '';
        meta.mainProgram = "warcraft3-reforged";
      };

      desktop = pkgs.makeDesktopItem {
        name = "warcraft3-reforged";
        desktopName = name;
        genericName = "Real-Time Strategy Game";
        comment = "Launch Warcraft III: Reforged through Proton";
        exec = "${package}/bin/warcraft3-reforged";
        icon = "applications-games";
        terminal = false;
        categories = [
          "Game"
          "StrategyGame"
        ];
        keywords = [
          "Warcraft"
          "Reforged"
          "Battle.net"
        ];
        startupWMClass = "Warcraft III.exe";
      };
    in
    {
      options.host.warcraft3 = {
        enable = lib.mkEnableOption "Warcraft III: Reforged through Battle.net and umu/Proton";

        prefixDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/warby/Games/warcraft3";
          description = ''
            Mutable Proton prefix holding Battle.net and the game. Kept apart
            from StarCraft's prefix because WC3 needs its own Proton build.
          '';
        };

        protonPath = lib.mkOption {
          type = lib.types.str;
          default = "/home/warby/.local/share/Steam/compatibilitytools.d/GE-Proton11-8-wc3fix";
          description = ''
            Proton build to run under umu. The default is GE-Proton11-8 with
            crypt32.dll (x86_64 and i386) taken from wine-staging 11.18, which
            works around the WC3 login bug in Wine 11.0 (fixed upstream in 11.6).
          '';
        };

        launchMode = lib.mkOption {
          type = lib.types.enum [
            "battlenet"
            "direct"
          ];
          default = "battlenet";
          description = ''
            How `warcraft3-reforged play` starts the game. "battlenet" opens
            the client, which ignores `--exec="launch W3"` on a cold start and
            waits for Play. "direct" starts Warcraft III.exe with the arguments
            Battle.net would pass; game patches still need the client.
          '';
        };

        gameArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [
            "-windowedmode"
            "windowed"
          ];
          description = ''
            Extra arguments for direct launches. Mirrors the client's
            "Additional command line arguments" for W3.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = lib.hasPrefix "/" cfg.prefixDir;
            message = "host.warcraft3.prefixDir must be an absolute path";
          }
          {
            assertion = lib.hasPrefix "/" cfg.protonPath;
            message = "host.warcraft3.protonPath must be an absolute path";
          }
        ];

        nixpkgs.config.allowUnfree = true;

        environment.systemPackages = [
          package
          desktop
        ];
      };
    };
}
