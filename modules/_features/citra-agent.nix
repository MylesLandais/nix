{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.host.citraAgent;

  bridgeSource = pkgs.writeText "citra-agent-bridge.py" (
    builtins.readFile ../../scripts/citra_agent_bridge.py
  );
  saveSyncSource = pkgs.writeText "three-ds-save-sync.py" (
    builtins.readFile ../../scripts/three_ds_save_sync.py
  );
  indexSource = pkgs.writeText "fe-echoes-index.py" (
    builtins.readFile ../../scripts/fe_echoes_index.py
  );

  checkpointChlink = pkgs.buildGoModule rec {
    pname = "checkpoint-chlink";
    version = "5.2.0";
    src = pkgs.fetchFromGitHub {
      owner = "BernardoGiordano";
      repo = "Checkpoint";
      rev = "ac9863c161ce440c225c02285ab89b4e1fb21424";
      hash = "sha256-wFvE1B9AVSkwVzFKgq5eKsPS/76Fb6gM8AlYhO3W8yU=";
    };
    sourceRoot = "${src.name}/tools/chlink";
    vendorHash = null;
    ldflags = [
      "-s"
      "-w"
      "-X main.version=${version}"
    ];
    meta = {
      description = "Checkpoint wireless save-transfer companion";
      homepage = "https://github.com/BernardoGiordano/Checkpoint/tree/v${version}/tools/chlink";
      license = lib.licenses.gpl3Only;
      mainProgram = "chlink";
    };
  };

  azaharMaya = pkgs.writeShellApplication {
    name = "azahar-maya";
    runtimeInputs = with pkgs; [
      azahar
      coreutils
      gamemode
    ];
    text = ''
      state_dir="''${CITRA_AGENT_STATE_DIR:-${cfg.stateDir}}"
      export XDG_DATA_HOME="''${XDG_DATA_HOME:-$state_dir/xdg/data}"
      export XDG_CONFIG_HOME="''${XDG_CONFIG_HOME:-$state_dir/xdg/config}"
      export XDG_CACHE_HOME="''${XDG_CACHE_HOME:-$state_dir/xdg/cache}"
      export QT_QPA_PLATFORM="''${QT_QPA_PLATFORM:-xcb}"
      mkdir -p -- "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
      exec gamemoderun azahar "$@"
    '';
  };

  citraAgentBridge = pkgs.writeShellApplication {
    name = "citra-agent-bridge";
    runtimeInputs = with pkgs; [
      ffmpeg
      python3
      xdotool
    ];
    text = ''
      export CITRA_AGENT_AZAHAR_BIN="''${CITRA_AGENT_AZAHAR_BIN:-${azaharMaya}/bin/azahar-maya}"
      export CITRA_AGENT_FFMPEG_BIN="''${CITRA_AGENT_FFMPEG_BIN:-${pkgs.ffmpeg}/bin/ffmpeg}"
      export CITRA_AGENT_XDOTOOL_BIN="''${CITRA_AGENT_XDOTOOL_BIN:-${pkgs.xdotool}/bin/xdotool}"
      exec ${pkgs.python3}/bin/python3 ${bridgeSource} "$@"
    '';
  };

  threeDsSaveSync = pkgs.writeShellApplication {
    name = "3ds-save-sync";
    runtimeInputs = [
      checkpointChlink
      pkgs.python3
    ];
    text = ''
      export CHECKPOINT_CHLINK_BIN="''${CHECKPOINT_CHLINK_BIN:-${checkpointChlink}/bin/chlink}"
      export CHECKPOINT_CHLINK_PORT="''${CHECKPOINT_CHLINK_PORT:-${toString cfg.wirelessPort}}"
      exec ${pkgs.python3}/bin/python3 ${saveSyncSource} "$@"
    '';
  };

  feEchoesIndex = pkgs.writeShellApplication {
    name = "fe-echoes-index";
    runtimeInputs = with pkgs; [
      ctrtool
      python3
    ];
    text = ''
      export CTRTOOL_BIN="''${CTRTOOL_BIN:-${pkgs.ctrtool}/bin/ctrtool}"
      exec ${pkgs.python3}/bin/python3 ${indexSource} "$@"
    '';
  };
in
{
  options.host.citraAgent = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.host.gamehacking.enable;
      description = "Enable the loopback Azahar control/observation bridge and owned-3DS tooling.";
    };

    gameRoot = lib.mkOption {
      type = lib.types.str;
      default = "/home/warby/Games/3DS";
      description = "Absolute root containing owned 3DS images accepted by the bridge.";
    };

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/home/warby/.local/state/citra-agent";
      description = "Mutable isolated Azahar, capture, and bridge state root.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 47833;
      description = "Loopback HTTP port used by Kino's game-agent client.";
    };

    gdbPort = lib.mkOption {
      type = lib.types.port;
      default = 24689;
      description = "Loopback Azahar GDB stub port used for bounded read-only memory observations.";
    };

    wirelessPort = lib.mkOption {
      type = lib.types.port;
      default = 18080;
      description = "LAN port opened for one-shot Checkpoint wireless save receives.";
    };

    display = lib.mkOption {
      type = lib.types.str;
      default = ":0";
      description = "X11/Xwayland display containing the Azahar XCB window.";
    };

    touchRect = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "0,240,400,240";
      description = "Optional x,y,width,height rectangle of Azahar's bottom screen for normalized touch tools.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "/" cfg.gameRoot;
        message = "host.citraAgent.gameRoot must be an absolute path";
      }
      {
        assertion = lib.hasPrefix "/" cfg.stateDir;
        message = "host.citraAgent.stateDir must be an absolute path";
      }
      {
        assertion =
          cfg.touchRect == null
          || builtins.match "^[0-9]+,[0-9]+,[1-9][0-9]*,[1-9][0-9]*$" cfg.touchRect != null;
        message = "host.citraAgent.touchRect must be x,y,width,height with positive width and height";
      }
    ];

    environment.systemPackages = [
      azaharMaya
      citraAgentBridge
      threeDsSaveSync
      feEchoesIndex
      pkgs.ctrtool
    ];

    networking.firewall.allowedTCPPorts = [ cfg.wirelessPort ];

    systemd.user.services.citra-agent-bridge = {
      description = "Loopback Azahar agent control and observation bridge";
      after = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      startLimitIntervalSec = 300;
      startLimitBurst = 5;
      environment = {
        CITRA_AGENT_AZAHAR_BIN = "${azaharMaya}/bin/azahar-maya";
        CITRA_AGENT_FFMPEG_BIN = "${pkgs.ffmpeg}/bin/ffmpeg";
        CITRA_AGENT_XDOTOOL_BIN = "${pkgs.xdotool}/bin/xdotool";
        CITRA_AGENT_STATE_DIR = cfg.stateDir;
        CITRA_AGENT_GAME_ROOT = cfg.gameRoot;
        CITRA_AGENT_PORT = toString cfg.port;
        CITRA_AGENT_GDB_PORT = toString cfg.gdbPort;
        DISPLAY = cfg.display;
        QT_QPA_PLATFORM = "xcb";
      }
      // lib.optionalAttrs (cfg.touchRect != null) {
        CITRA_AGENT_TOUCH_RECT = cfg.touchRect;
      };
      serviceConfig = {
        Type = "simple";
        ExecStart = "${citraAgentBridge}/bin/citra-agent-bridge --host 127.0.0.1 --port ${toString cfg.port} --state-dir ${lib.escapeShellArg cfg.stateDir} --game-root ${lib.escapeShellArg cfg.gameRoot}";
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStopSec = 10;
        UMask = "0077";
        StateDirectory = "citra-agent";
        StateDirectoryMode = "0700";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = "read-only";
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
        ];
      };
    };
  };
}
