{ pkgs, ... }:
let
  diskPlaybook = pkgs.writeShellScriptBin "disk-playbook" ''
    exec ${pkgs.lua5_4}/bin/lua ${./../../scripts/disk-playbook.lua} "$@"
  '';
in
{
  home.packages = [ diskPlaybook ];

  systemd.user.services.disk-maintenance = {
    Unit = {
      Description = "Nightly disk space monitoring, reporting, and maintenance";
      Documentation = [ "file://${./../../scripts/disk-playbook.lua}" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${diskPlaybook}/bin/disk-playbook nightly";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.disk-maintenance = {
    Unit.Description = "Nightly disk maintenance and health report";
    Timer = {
      OnCalendar = "*-*-* 03:30:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
      Unit = "disk-maintenance.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
