_: {
  flake.modules.nixos.iw4x =
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
        text = builtins.replaceStrings
            [ "@NIX1@" "@NIX2@" "@NIX3@" "@NIX4@" "@NIX5@" "@NIX6@" ]
            [
              "${lib.escapeShellArg cfg.gameDir}"
              "${lib.escapeShellArg cfg.prefixDir}"
              "${pkgs.iw4x-launcher}"
              "${lib.escapeShellArg (toString pkgs.proton-ge-bin.steamcompattool)}"
              "${pkgs.gamemode}"
              "${pkgs.umu-launcher}"
            ]
            (builtins.readFile ./iw4x.sh);
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
          default = "${
            config.users.users.${config.host.username}.home
          }/.local/share/Steam/steamapps/common/Call of Duty Modern Warfare 2";
          defaultText = lib.literalExpression ''"''${config.users.users.''${config.host.username}.home}/.local/share/Steam/steamapps/common/Call of Duty Modern Warfare 2"'';
          description = "Mutable MW2 game directory used by the IW4x updater and runtime.";
        };

        prefixDir = lib.mkOption {
          type = lib.types.str;
          default = "${config.users.users.${config.host.username}.home}/.local/share/iw4x/compatdata/10190";
          defaultText = lib.literalExpression ''"''${config.users.users.''${config.host.username}.home}/.local/share/iw4x/compatdata/10190"'';
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
