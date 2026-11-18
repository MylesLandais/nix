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
        text =
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
            ]
            [
              "${lib.escapeShellArg cfg.prefixDir}"
              "${lib.escapeShellArg cfg.protonPath}"
              "${name}"
              "${gameId}"
              "${gameId}"
              "${gameId}"
              "${name}"
              "${gameId}"
              "${hiddenGameId}"
              "${hiddenGameId}"
              "${gameId}"
            ]
            (builtins.readFile ./warcraft3-launcher.sh);
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
          default = "${config.users.users.${config.host.username}.home}/Games/warcraft3";
          defaultText = lib.literalExpression ''"''${config.users.users.''${config.host.username}.home}/Games/warcraft3"'';
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
