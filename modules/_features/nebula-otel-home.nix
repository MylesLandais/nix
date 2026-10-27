# Incremental log delivery, independent of the legacy Docker collector.
# No listener and no boot-time Docker dependency. Activation is a normal Nix switch.
{ config, pkgs, ... }:
let
  sourceRoot = "${config.home.homeDirectory}/Workspace/data/training-state/klein-pilot";
  collectorConfig = ../../files/observability/experiment-logs.json;
  environment = [
    "NEBULA_LOG_SOURCE_ROOT=${sourceRoot}"
    "NEBULA_OTEL_STATE=%S/nebula-otel"
    "NEBULA_CLICKHOUSE_ENDPOINT=http://127.0.0.1:8123"
  ];
in
{
  systemd.user = {
    services = {
      nebula-log-collector = {
        Unit = {
          Description = "Retain and send experiment logs to local ClickHouse";
          StartLimitIntervalSec = 300;
          StartLimitBurst = 5;
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.opentelemetry-collector-contrib}/bin/otelcol-contrib --config=${collectorConfig}";
          Environment = environment ++ [
            "PATH=${pkgs.systemd}/bin"
            "GOMEMLIMIT=384MiB"
          ];
          StateDirectory = "nebula-otel";
          StateDirectoryMode = "0700";
          UMask = "0077";
          Restart = "on-failure";
          RestartSec = 10;
          KillSignal = "SIGINT";
          TimeoutStopSec = 30;
          CPUQuota = "100%";
          MemoryHigh = "384M";
          MemoryMax = "512M";
          Nice = 10;
          NoNewPrivileges = true;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      nebula-log-delivery-check = {
        Unit = {
          Description = "Verify end-to-end experiment log delivery";
          StartLimitIntervalSec = 300;
          StartLimitBurst = 3;
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.python3}/bin/python3 ${../../scripts/check-nebula-log-delivery.py}";
          Environment = environment;
          StateDirectory = "nebula-otel";
          StateDirectoryMode = "0700";
          UMask = "0077";
          TimeoutStartSec = 40;
          CPUQuota = "25%";
          MemoryMax = "128M";
          Nice = 15;
          NoNewPrivileges = true;
        };
      };

    };
    timers.nebula-log-delivery-check = {
      Unit = {
        Description = "Check experiment log delivery every five minutes after login";
        PartOf = [ "graphical-session.target" ];
      };
      Timer = {
        OnActiveSec = "1m";
        OnUnitInactiveSec = "5m";
        Unit = "nebula-log-delivery-check.service";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
