_: {
  flake.nixosModules.iw4x =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.host.iw4x;

      iw4x = pkgs.writeShellApplication {
        name = "iw4x";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          default_game_dir=${lib.escapeShellArg cfg.gameDir}
          default_prefix_dir=${lib.escapeShellArg cfg.prefixDir}
          game_dir="''${IW4X_GAME_DIR:-$default_game_dir}"
          prefix_dir="''${IW4X_PREFIX_DIR:-$default_prefix_dir}"
          mode=normal

          usage() {
            cat <<'EOF'
          Usage: iw4x [--offline | --repair] [-- GAME_ARGS...]

            normal     update IW4x, then launch it through UMU/Proton
            --repair   force launcher file verification before launch
            --offline  skip all IW4x network update checks

          IW4X_GAME_DIR and IW4X_PREFIX_DIR override the configured paths.
          EOF
          }

          case "''${1:-}" in
            -h|--help)
              usage
              exit 0
              ;;
            --offline|--repair)
              mode="''${1#--}"
              shift
              ;;
          esac
          if [ "''${1:-}" = "--" ]; then
            shift
          elif [ "''${1:-}" = "--offline" ] || [ "''${1:-}" = "--repair" ]; then
            echo "iw4x: only one launch mode may be selected" >&2
            exit 2
          elif [[ "''${1:-}" = --* ]]; then
            echo "iw4x: unknown option: $1" >&2
            usage >&2
            exit 2
          fi

          required=(binkw32.dll mss32.dll iw4mp.exe)
          for file in "''${required[@]}"; do
            if [ ! -f "$game_dir/$file" ]; then
              echo "iw4x: required MW2 file is missing: $game_dir/$file" >&2
              echo "iw4x: restore or install the supported base game before launching" >&2
              exit 1
            fi
          done

          if [ "$mode" != offline ]; then
            launcher_args=(
              --path "$game_dir"
              --update
              --skip-self-update
              --disable-art
            )
            if [ "$mode" = repair ]; then
              launcher_args+=(--force)
            fi
            ${pkgs.iw4x-launcher}/bin/iw4x-launcher "''${launcher_args[@]}"
          fi

          if [ ! -f "$game_dir/iw4x.exe" ]; then
            echo "iw4x: IW4x client is missing: $game_dir/iw4x.exe" >&2
            if [ "$mode" = offline ]; then
              echo "iw4x: run a normal online launch once before using --offline" >&2
            fi
            exit 1
          fi

          mkdir -p -- "$prefix_dir"
          export WINEPREFIX="$prefix_dir"
          export GAMEID=umu-10190
          export STORE=steam
          export PROTONPATH=${lib.escapeShellArg (toString pkgs.proton-ge-bin.steamcompattool)}

          exec ${pkgs.gamemode}/bin/gamemoderun \
            ${pkgs.umu-launcher}/bin/umu-run \
            "$game_dir/iw4x.exe" \
            -stdout \
            "$@"
        '';
      };

      iw4xRuntime = pkgs.symlinkJoin {
        name = "iw4x-runtime-${pkgs.iw4x-launcher.version}";
        paths = [ iw4x ];
      };

      iw4xPack = pkgs.writeShellApplication {
        name = "iw4x-pack";
        runtimeInputs = with pkgs; [
          b3sum
          coreutils
          file
          findutils
          gnutar
          jq
          nix
          p7zip
          par2cmdline-turbo
          rsync
          unzip
          util-linux
          zstd
        ];
        text = ''
          export IW4X_RUNTIME_CLOSURE_ROOT=${lib.escapeShellArg (toString iw4xRuntime)}
          export IW4X_LAUNCHER_VERSION=${lib.escapeShellArg pkgs.iw4x-launcher.version}
          export IW4X_UMU_VERSION=${lib.escapeShellArg pkgs.umu-launcher.version}
          export IW4X_PROTON_VERSION=${lib.escapeShellArg pkgs.proton-ge-bin.version}
          ${builtins.readFile ../../scripts/iw4x-pack.sh}
        '';
      };

      iw4xDesktop = pkgs.makeDesktopItem {
        name = "iw4x";
        desktopName = "IW4x";
        genericName = "Game";
        comment = "Update and launch IW4x through UMU/Proton";
        exec = "${pkgs.ghostty}/bin/ghostty --class=iw4x-launcher -e ${iw4x}/bin/iw4x";
        icon = "applications-games";
        terminal = false;
        categories = [ "Game" ];
        keywords = [
          "Call of Duty"
          "Modern Warfare 2"
          "IW4x"
        ];
        startupWMClass = "iw4x.exe";
      };
    in
    {
      options.host.iw4x = {
        enable = lib.mkEnableOption "IW4x updater, UMU runtime, and offline archive tooling";

        gameDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/warby/.local/share/Steam/steamapps/common/Call of Duty Modern Warfare 2";
          description = "Mutable MW2 game directory used by the IW4x updater and runtime.";
        };

        prefixDir = lib.mkOption {
          type = lib.types.str;
          default = "/home/warby/.local/share/iw4x/compatdata/10190";
          description = "Dedicated UMU/Proton prefix for IW4x.";
        };
      };

      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = lib.hasPrefix "/" cfg.gameDir;
            message = "host.iw4x.gameDir must be an absolute path";
          }
          {
            assertion = lib.hasPrefix "/" cfg.prefixDir;
            message = "host.iw4x.prefixDir must be an absolute path";
          }
        ];

        programs.steam.extraCompatPackages = lib.mkAfter [ pkgs.proton-ge-bin ];

        environment.systemPackages = [
          iw4x
          iw4xPack
          iw4xDesktop
          pkgs.iw4x-launcher
          pkgs.umu-launcher
        ];
      };
    };
}
