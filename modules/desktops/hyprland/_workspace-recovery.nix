# Hyprland multi-monitor workspace recovery (watch socket + suspend resume).
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.hyprland.workspaceRecovery;

  managedWorkspaces = lib.filter (w: builtins.hasAttr w cfg.mappings) [
    "1"
    "2"
    "3"
    "4"
    "5"
    "6"
    "7"
    "8"
    "9"
    "10"
  ];

  headlessWorkspace = "99";

  defaultTargetsBash = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (ws: target: ''["${ws}"]=${lib.escapeShellArg target}'') cfg.mappings
  );

  jqDefaultArgs = lib.concatStringsSep " \\\n          " (
    lib.mapAttrsToList (ws: target: ''--arg default_${ws} "${target}"'') cfg.mappings
  );

  jqDefaultObject = lib.concatStringsSep "\n                  " (
    lib.mapAttrsToList (ws: _target: ''"${ws}": $default_${ws},'') cfg.mappings
  );

  hyprland_workspace_recovery = pkgs.writeShellApplication {
    name = "hyprland-workspace-recovery";
    runtimeInputs = with pkgs; [
      bash
      coreutils
      gnugrep
      jq
      socat
      util-linux
    ];
    text = builtins.replaceStrings
        [ "@NIX1@" "@NIX2@" "@NIX3@" "@NIX4@" "@NIX5@" "@NIX6@" ]
        [
          "${lib.concatStringsSep " " (map (w: "\"${w}\"") managedWorkspaces)}"
          "${headlessWorkspace}"
          "${defaultTargetsBash}"
          "${jqDefaultArgs}"
          "${lib.concatStringsSep "," managedWorkspaces}"
          "${jqDefaultObject}"
        ]
        (builtins.readFile ./workspace-recovery.sh);
  };
in
{
  options.my.hyprland.workspaceRecovery = {
    enable = lib.mkEnableOption "Hyprland workspace-to-monitor recovery on topology changes";

    mappings = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Workspace ID (string keys) to monitor identifier (Hyprland output name or desc:… stable id).
        Include workspace "99" for the headless output mapping when used.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.mappings != { };
        message = "hyprland.workspaceRecovery.enable requires non-empty mappings";
      }
    ];

    home.packages = [ hyprland_workspace_recovery ];

    systemd.user.services.hyprland-workspace-recovery = {
      Unit = {
        Description = "Watch Hyprland monitor events and recover workspace mapping";
        After = [
          "graphical-session.target"
          "hyprland-session.target"
        ];
        BindsTo = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        Wants = [ "hyprland-session.target" ];
        # Restart=always with a 2s interval; without a ceiling a persistently
        # failing watcher would respawn ~1800 times an hour.
        StartLimitIntervalSec = 300;
        StartLimitBurst = 10;
      };
      Service = {
        ExecStart = "${hyprland_workspace_recovery}/bin/hyprland-workspace-recovery watch";
        Restart = "always";
        RestartSec = "2s";
        Environment = [ "XDG_CURRENT_DESKTOP=Hyprland" ];
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    systemd.user.services.hyprland-workspace-recover-resume = {
      Unit = {
        Description = "Recover Hyprland workspaces after suspend/resume";
        After = [
          "suspend.target"
          "graphical-session.target"
          "hyprland-session.target"
        ];
        BindsTo = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        Wants = [ "hyprland-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${hyprland_workspace_recovery}/bin/hyprland-workspace-recovery recover --reason resume";
        Environment = [ "XDG_CURRENT_DESKTOP=Hyprland" ];
      };
      Install.WantedBy = [ "suspend.target" ];
    };
  };
}
