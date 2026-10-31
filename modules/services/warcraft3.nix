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

      # GE-Proton11-7 and later carry the crypt32 fix for the WC3 3.0 "check
      # your VPN" login error (proton-ge-custom PR #765); 11-11 was verified
      # signing in on 2026-10-30. A binary repack, so overriding the version
      # only downloads a release tarball.
      geProton = pkgs.proton-ge-bin.overrideAttrs (
        finalAttrs: old: {
          version = "GE-Proton11-11";
          __intentionallyOverridingVersion = true;
          passthru = old.passthru // {
            variants = old.passthru.variants // {
              x86_64-linux = {
                toolName = "${finalAttrs.version}-x86_64";
                src = pkgs.fetchzip {
                  url = "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${finalAttrs.version}/${finalAttrs.version}-x86_64.tar.gz";
                  hash = "sha256-3tVgf83IkteFtVo/bHd4yG1xCtPeuW8FXaTrHOLjvKQ=";
                };
              };
            };
          };
        }
      );

      # Battle.net windows from a pre-warmed session get this class
      # (umu maps GAMEID=umu-<id> to steam_app_<id>) so Hyprland can park them
      # on a hidden special workspace without touching the game window.
      hiddenGameId = "battlenet";
      gameId = "warcraft3";

      launcher = pkgs.writeShellApplication {
        name = "warcraft3-reforged";
        runtimeInputs = with pkgs; [
          coreutils
          curl
          gamemode
          gnugrep
          procps
          umu-launcher
        ];
        text = ''
          prefix_dir=${lib.escapeShellArg cfg.prefixDir}
          export PROTONPATH=${lib.escapeShellArg cfg.protonPath}

          drive_c="$prefix_dir/drive_c"
          battle_net_exe="$drive_c/Program Files (x86)/Battle.net/Battle.net.exe"
          game_exe="$drive_c/Program Files (x86)/Warcraft III/_retail_/x86_64/Warcraft III.exe"
          # Proton runs everything as "steamuser"; this is the file the client reads.
          battle_net_config="$drive_c/users/steamuser/AppData/Roaming/Battle.net/Battle.net.config"
          battle_net_logs="$drive_c/users/steamuser/AppData/Local/Battle.net/Logs"
          state_dir="''${XDG_RUNTIME_DIR:-/tmp}/warcraft3-reforged"
          mkdir -p -- "$state_dir"

          usage() {
            cat <<'EOF'
          Usage: warcraft3-reforged [play|prewarm|battlenet|stop|install|status|debug|help]

            play       launch WC3 through Battle.net without pressing Play; reuses a
                       running (pre-warmed) client, otherwise starts one and waits
                       for its sign-in
            prewarm    start Battle.net hidden and signed in, ready for a fast play
            battlenet  show the Battle.net client (patches, settings, sign-in)
            stop       end the Battle.net/WC3 Wine session
            install    install Battle.net into the prefix, then sign in and install WC3
            status     report prefix, Proton, session, and ntsync state
            debug      like play, with a Proton log written to the prefix

          With no command, the launcher installs when needed, then plays.
          The command is also available as: wc3
          EOF
          }

          use_proton() {
            if [ ! -x "$PROTONPATH/proton" ]; then
              echo "Proton build not found: $PROTONPATH" >&2
              exit 1
            fi
            if [ "''${DISPLAY:-}" = ":0" ] && [ ! -S /tmp/.X11-unix/X0 ]; then
              # Without the X0 socket Wine falls back to its Wayland driver,
              # where the WC3 menu renders black.
              echo "warning: /tmp/.X11-unix/X0 is missing; WC3 will likely render black" >&2
            fi
            export WINEPREFIX="$prefix_dir"
            export GAMEID="umu-$1"
            # Lets a later umu-run re-enter the running container, so a second
            # --exec reaches the signed-in client instead of starting another.
            export UMU_CONTAINER_NSENTER=1
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

          # Prints the PID of the first Wine process in this prefix whose
          # Windows command line matches $1 (helper processes excluded).
          wine_pid() {
            local pid args
            while read -r pid args; do
              case "$args" in C:\\*) ;; *) continue ;; esac
              case "$args" in *--type=*) continue ;; esac
              [[ "$args" =~ $1 ]] || continue
              if grep -qzE "^WINEPREFIX=$prefix_dir(/|$)" "/proc/$pid/environ" 2>/dev/null; then
                printf '%s\n' "$pid"
                return 0
              fi
            done < <(ps -eo pid=,args=)
            return 1
          }
          client_running() { wine_pid 'Battle\.net\\Battle\.net\.exe' >/dev/null; }
          game_running() { wine_pid 'Warcraft III\.exe' >/dev/null; }

          # True once the client started by this session has signed in.
          signed_in() {
            local log
            [ -f "$state_dir/session-start" ] || return 1
            while read -r log; do
              grep -q 'Logged into Battle.net successfully' "$log" && return 0
            done < <(find "$battle_net_logs" -maxdepth 1 -name 'battle.net-*.log' -newer "$state_dir/session-start" 2>/dev/null)
            return 1
          }

          wait_for() {
            local check=$1 seconds=$2
            for _ in $(seq 1 "$((seconds * 2))"); do
              "$check" && return 0
              sleep 0.5
            done
            return 1
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

          # Starts the Battle.net session. $1 is the umu GAMEID suffix, which
          # sets the window class; $2=foreground keeps it attached (systemd).
          start_client() {
            seed_battle_net_config
            use_proton "$1"
            touch "$state_dir/session-start"
            if [ "''${2:-}" = foreground ]; then
              gamemoded -r"$$" >/dev/null 2>&1 || true
              exec umu-run "$battle_net_exe"
            fi
            setsid umu-run "$battle_net_exe" >"$state_dir/umu.log" 2>&1 </dev/null &
            # GameMode's LD_PRELOAD can't find libgamemode inside the Steam
            # Runtime container, so register the host-side umu process instead;
            # it lives for the whole session.
            gamemoded -r"$!" >/dev/null 2>&1 || true
          }

          show_hidden_client() {
            command -v hyprctl >/dev/null &&
              hyprctl eval 'hl.dsp.workspace.toggle_special("battlenet")' >/dev/null 2>&1 || true
          }

          play() {
            if game_running; then
              echo "${name} is already running."
              return 0
            fi
            if ! client_running; then
              start_client ${gameId}
            fi
            if ! wait_for signed_in 120; then
              show_hidden_client
              echo "Battle.net has not signed in; sign in there, then run: warcraft3-reforged" >&2
              exit 1
            fi
            sleep 3
            # Battle.net ignores --exec on its own cold start, but honours it
            # from a second instance once signed in.
            for _ in 1 2 3; do
              use_proton ${gameId}
              umu-run "$battle_net_exe" --exec="launch W3" >>"$state_dir/umu.log" 2>&1 </dev/null &
              wait_for game_running 15 && return 0
            done
            echo "Battle.net did not start the game; press Play in the client." >&2
            show_hidden_client
            exit 1
          }

          stop_session() {
            local pid args killed=0
            while read -r pid args; do
              case "$args" in [Cc]:*) ;; *) continue ;; esac
              if grep -qzE "^WINEPREFIX=$prefix_dir(/|$)" "/proc/$pid/environ" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null && killed=$((killed + 1))
              fi
            done < <(ps -eo pid=,args=)
            rm -f -- "$state_dir/session-start"
            echo "Stopped $killed Wine processes."
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
            use_proton ${gameId}
            echo "Installing Battle.net. Sign in, then install ${name} from the client."
            exec umu-run "$setup"
          }

          show_status() {
            failed=0
            echo "prefix: $prefix_dir"
            if [ -x "$PROTONPATH/proton" ]; then
              echo "Proton: $(cat "$PROTONPATH/version" 2>/dev/null || echo present) ($PROTONPATH)"
            else
              echo "Proton: missing ($PROTONPATH)"
              failed=1
            fi
            if [ -f "$battle_net_exe" ]; then echo "Battle.net: installed"; else echo "Battle.net: missing"; failed=1; fi
            if [ -f "$game_exe" ]; then echo "Warcraft III: installed"; else echo "Warcraft III: missing"; failed=1; fi
            if client_running; then
              if signed_in; then echo "session: Battle.net running, signed in"; else echo "session: Battle.net running, not signed in"; fi
            else
              echo "session: no Battle.net client"
            fi
            if game_running; then echo "game: running"; fi
            if [ -c /dev/ntsync ]; then
              echo "ntsync: available"
            else
              echo "ntsync: missing (Proton falls back to fsync)"
            fi
            return "$failed"
          }

          action="''${1:-open}"
          case "$action" in
            open)
              if [ -f "$game_exe" ]; then
                play
              elif [ -f "$battle_net_exe" ]; then
                client_running || start_client ${gameId}
              else
                install_battle_net
              fi
              ;;
            play) play ;;
            prewarm)
              if client_running; then
                echo "Battle.net is already running."
              elif [ -n "''${WC3_FOREGROUND:-}" ]; then
                start_client ${hiddenGameId} foreground
              else
                start_client ${hiddenGameId}
              fi
              ;;
            battlenet)
              if client_running; then show_hidden_client; else start_client ${gameId}; fi
              ;;
            stop) stop_session ;;
            install) install_battle_net ;;
            status) show_status ;;
            debug)
              export PROTON_LOG=1
              export PROTON_LOG_DIR="$prefix_dir"
              echo "Proton log: $prefix_dir/steam-*.log"
              play
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
        comment = "Launch Warcraft III: Reforged through Battle.net and Proton";
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
        startupWMClass = "steam_app_${gameId}";
      };
    in
    {
      options.host.warcraft3 = {
        enable = lib.mkEnableOption "Warcraft III: Reforged through Battle.net and umu/Proton";

        prefixDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/warby/Games/warcraft3";
          description = ''
            Mutable Proton prefix holding Battle.net and the game, kept apart
            from StarCraft's prefix.
          '';
        };

        protonPath = lib.mkOption {
          type = lib.types.str;
          default = "${geProton.steamcompattool}";
          defaultText = lib.literalExpression ''"''${proton-ge-bin (GE-Proton11-11)}.steamcompattool"'';
          description = "Proton build run by umu. Must be GE-Proton11-7 or newer for the WC3 login fix.";
        };

        prewarm = {
          enable = lib.mkEnableOption ''
            starting Battle.net hidden after login, so `wc3` launches the game
            without waiting for the client. An idle signed-in client measured
            about 2.5 GB RSS and 35% of one core before ntsync
          '';

          delay = lib.mkOption {
            type = lib.types.str;
            default = "2min";
            description = "How long after the graphical session starts to pre-warm Battle.net (systemd time span).";
          };
        };

        hyprlandExtraConfig = lib.mkOption {
          type = lib.types.str;
          default = "";
          internal = true;
          description = "Hyprland Lua window rule parking pre-warmed Battle.net windows on special:battlenet.";
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

        host.warcraft3.hyprlandExtraConfig = ''
          hl.window_rule({ workspace = "special:battlenet silent", match = { class = "^(steam_app_${hiddenGameId})$", title = "^(Battle\\.net)" } })
        '';

        environment.systemPackages = [
          package
          desktop
        ];

        # Started after the graphical session, not at boot: the user lingers,
        # so a timers.target hook would fire before any display exists.
        systemd.user.services.warcraft3-prewarm = lib.mkIf cfg.prewarm.enable {
          description = "Pre-warm Battle.net for Warcraft III: Reforged";
          after = [ "graphical-session.target" ];
          partOf = [ "graphical-session.target" ];
          environment.WC3_FOREGROUND = "1";
          serviceConfig = {
            Type = "simple";
            ExecStart = "${package}/bin/warcraft3-reforged prewarm";
          };
        };
        systemd.user.timers.warcraft3-prewarm = lib.mkIf cfg.prewarm.enable {
          wantedBy = [ "graphical-session.target" ];
          partOf = [ "graphical-session.target" ];
          timerConfig.OnActiveSec = cfg.prewarm.delay;
        };
      };
    };
}
