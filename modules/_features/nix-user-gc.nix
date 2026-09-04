# Home-manager module: garbage-collect the per-user Nix profile.
#
# `nix.gc.automatic` in modules/_features/nix-config.nix only prunes *system*
# generations. It does not touch `~/.local/state/nix/profiles/profile-*-link`,
# and `nix-collect-garbage -d` cannot free them either — only
# `nix profile wipe-history` can. That gap let 879 user-profile generations
# accumulate, each pinning a full closure, and drove /nix to 743 GiB on
# 2026-09-02 (see ~/Vault/nix-issues/nix-store-budget-and-gc-runbook.md).
#
# This timer closes it. It only drops generation *history*; the current
# generation is always kept, so nothing installed is ever removed.
{ pkgs, ... }:
{
  systemd.user.services.nix-profile-wipe-history = {
    Unit.Description = "Prune old per-user Nix profile generations";
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.nix}/bin/nix profile wipe-history --older-than 7d";
    };
  };

  systemd.user.timers.nix-profile-wipe-history = {
    Unit.Description = "Weekly per-user Nix profile history prune";
    Timer = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
      Unit = "nix-profile-wipe-history.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
