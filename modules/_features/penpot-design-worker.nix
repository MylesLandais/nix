# An isolated design session, started after login rather than on the boot path.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.penpotDesignWorker;
  runtime = "%t/nebula-penpot";
  state = "${config.xdg.stateHome}/penpot-design-worker";
  run = pkgs.writeShellApplication {
    name = "penpot-design-session";
    runtimeInputs = [
      pkgs.nodejs
      pkgs.libsecret
      pkgs.xvfb-run
      pkgs.coreutils
    ];
    text = ''
      export BROKER_EXECUTION_TOKEN_KEY
      BROKER_EXECUTION_TOKEN_KEY=$(secret-tool lookup service penpot-design-execution username ${lib.escapeShellArg config.home.username})
      export PENPOT_DATABASE_URL
      PENPOT_DATABASE_URL=$(secret-tool lookup service penpot-design-database username ${lib.escapeShellArg config.home.username})
      test -n "$BROKER_EXECUTION_TOKEN_KEY" && test -n "$PENPOT_DATABASE_URL"
      source_root="''${PENPOT_WORKSPACE:-${cfg.workspaceRoot}}"
      gateway="''${PENPOT_GATEWAY_BINARY:-$source_root/target/debug/nebula-penpot-gateway}"
      test -x "$gateway"
      test -f "$source_root/apps/browser-worker/src/penpot/worker.mjs"
      # These sockets belong to this unit's private RuntimeDirectory. systemd
      # kills the complete old cgroup before starting a replacement.
      rm -f "$PENPOT_WORKER_SOCKET" "$PENPOT_GATEWAY_SOCKET"
      xvfb-run -a -s '-screen 0 1600x1000x24 -nolisten tcp' \
        node "$source_root/apps/browser-worker/src/penpot/worker.mjs" &
      worker=$!
      trap 'kill "$worker" "''${gateway_pid:-}" 2>/dev/null || true' EXIT
      for _attempt in $(seq 1 45); do
        test -S "$PENPOT_WORKER_SOCKET" && break
        kill -0 "$worker" 2>/dev/null || exit 1
        sleep 1
      done
      test -S "$PENPOT_WORKER_SOCKET"
      "$gateway" &
      gateway_pid=$!
      # A failed child ends this session. The bounded systemd restart policy
      # recovers it; PostgreSQL retains all unfinished operation receipts.
      wait -n "$worker" "$gateway_pid"
      exit 1
    '';
  };
in
{
  options.penpotDesignWorker = {
    enable = lib.mkEnableOption "isolated Chromium Penpot design worker and local Rust gateway";
    workspaceRoot = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/Workspace";
      description = "Reviewed Workspace checkout containing the Penpot worker and gateway binary.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ run ];
    systemd.user.services.penpot-design-session = {
      Unit = {
        Description = "Isolated Penpot design worker and coordinated agent gateway";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        ConditionPathExists = "${state}/target.json";
        StartLimitIntervalSec = 300;
        StartLimitBurst = 3;
      };
      Service = {
        Type = "simple";
        ExecStart = lib.getExe run;
        Environment = [
          "PENPOT_WORKER_STATE=${state}"
          "PENPOT_TARGET_CONFIG=${state}/target.json"
          "PENPOT_WORKER_SOCKET=${runtime}/worker.sock"
          "PENPOT_GATEWAY_SOCKET=${runtime}/gateway.sock"
          "PENPOT_PLAYWRIGHT_PACKAGE=${pkgs.playwright-driver}/package.json"
          "CHROMIUM_PATH=${lib.getExe pkgs.chromium}"
          "WAYLAND_DISPLAY="
        ];
        EnvironmentFile = "-${config.xdg.configHome}/nebula/penpot-design-session.env";
        RuntimeDirectory = "nebula-penpot";
        RuntimeDirectoryMode = "0700";
        StateDirectory = "penpot-design-worker";
        StateDirectoryMode = "0700";
        UMask = "0077";
        PrivateTmp = true;
        Restart = "on-failure";
        RestartSec = 10;
        TimeoutStopSec = 20;
        KillMode = "control-group";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
