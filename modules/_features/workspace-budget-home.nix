# Cerberus workspace compute budget, user half (see workspace-budget.nix and
# docs/infra/workspace-compute-budget.md). The monorepo's launchers create the
# nebula-* units as transient `systemd-run --user` services; the prefix
# drop-in places every one of them in workspace.slice without the monorepo
# carrying machine-specific policy.
_: {
  systemd.user.slices.workspace = {
    Unit.Description = "Workspace user workloads (nebula-* services)";
    Slice = {
      CPUQuota = "400%";
      CPUWeight = 20;
      # The user manager delegates cpu/memory/pids only, so no IO weights.
      MemoryHigh = "24G";
      MemoryMax = "32G";
      ManagedOOMMemoryPressure = "kill";
      ManagedOOMMemoryPressureLimit = "60%";
    };
  };

  xdg.configFile."systemd/user/nebula-.service.d/10-workspace-slice.conf".text = ''
    [Service]
    Slice=workspace.slice
  '';

  # Dormant CDP Chrome used by automation; same budget when it is started.
  xdg.configFile."systemd/user/chrome-cdp.service.d/10-workspace-slice.conf".text = ''
    [Service]
    Slice=workspace.slice
  '';
}
