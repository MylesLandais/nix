# Cerberus workspace compute budget, system half. The user half (nebula-*
# services) is workspace-budget-home.nix. Policy and acceptance criteria:
# docs/infra/workspace-compute-budget.md.
#
# Two aggregate ceilings totalling 6 of the 12 logical CPUs: 400% for
# workspace user workloads, 200% for Nix and host workloads. CPUWeight keeps
# both behind the desktop when the CPU is contended, even below the ceiling.
{ lib, ... }:
{
  systemd.slices.workspace-host = {
    description = "Workspace host workloads (Nix builds)";
    sliceConfig = {
      CPUQuota = "200%";
      CPUWeight = 20;
      IOWeight = 20;
      # The doc proposed 12G/16G. nix-daemon measured a 26G peak on
      # 2026-10-22, and the doc forbids hard limits below current use.
      MemoryHigh = "24G";
      MemoryMax = "32G";
    };
  };

  systemd.services.nix-daemon.serviceConfig.Slice = "workspace-host.slice";

  # One derivation at a time with two build cores. Overrides the 2 x 6 in
  # hardware-tuning.nix. For a large cache-miss rebuild, pass
  # `--max-jobs N --cores M` explicitly. The 200% quota still applies.
  nix.settings = {
    max-jobs = lib.mkForce 1;
    cores = lib.mkForce 2;
  };

  # Docker containers are deliberately not moved here yet. docker.service has
  # restartIfChanged = true and live-restore = false, so changing
  # daemon.json (cgroup-parent) restarts every container: Postgres, vLLM and
  # the crawler. Per the doc that waits for the inventory and a drained
  # window. vLLM's --cpu-offload-gb also exceeds the host memory ceiling above.
}
