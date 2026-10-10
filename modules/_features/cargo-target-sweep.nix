# Home-manager module: aggressively prune Cargo build output.
#
# Every worktree under ~/Workspace-git carries its own target/, and a single
# `cargo test --workspace --tests` in nebula leaves ~250 fully linked test
# binaries behind. On 2026-10-09 the seven target dirs held ~265 GiB, with
# Workspace-git/dev/target alone at 145 GiB.
#
# Two passes per project, both with cargo-sweep:
#   1. --time   drop artifacts not used for MAX_AGE_DAYS (dead worktrees go
#               to near zero on their own)
#   2. --maxsize  cap what is left at MAX_SIZE, oldest artifacts first (a hot
#               tree is all "recent", so age alone frees nothing there)
#
# Cargo flocks target/<profile>/.cargo-*lock while it builds. A project whose
# lock is held, or with a cargo/rustc running inside it, is skipped. The locks
# are held during the sweep so a build started meanwhile waits instead of
# losing files under it.
{ pkgs, ... }:
let
  sweep = pkgs.writeShellApplication {
    name = "cargo-target-sweep";
    runtimeInputs = with pkgs; [
      cargo # cargo-sweep shells out to `cargo metadata`
      cargo-sweep
      coreutils
      findutils
      util-linux
    ];
    text = ''
      MAX_AGE_DAYS=''${MAX_AGE_DAYS:-3}
      MAX_SIZE=''${MAX_SIZE:-30GB}
      roots=("$HOME/Workspace" "$HOME/Workspace-git")
      dry=()
      [ "''${1:-}" = "--dry-run" ] && dry=(--dry-run)

      find "''${roots[@]}" -maxdepth 6 \
          \( -name node_modules -o -name .git \) -prune -o \
          -type d -name target -print -prune 2>/dev/null |
      while read -r target; do
        project=$(dirname "$target")
        # A target/ without a Cargo.toml beside it may be source, not output.
        [ -f "$project/Cargo.toml" ] || continue

        busy=0
        fds=()
        # Cargo drops its locks once `cargo test` moves on to running the test
        # binaries, so also skip while any cargo/rustc is working in here.
        for p in /proc/[0-9]*; do
          case $(cat "$p/comm" 2>/dev/null) in
            cargo | rustc | rustdoc) ;;
            *) continue ;;
          esac
          cwd=$(readlink "$p/cwd" 2>/dev/null) || continue
          case "$cwd/" in "$project"/*) busy=1; break ;; esac
        done
        [ "$busy" = 1 ] || while read -r lock; do
          exec {fd}<>"$lock"
          if flock -n "$fd"; then fds+=("$fd"); else busy=1; break; fi
        done < <(find "$target" -maxdepth 2 -name '.cargo-*lock')

        if [ "$busy" = 1 ]; then
          echo "skip (build running)  $target"
        else
          before=$(du -sh "$target" | cut -f1)
          cargo-sweep sweep "''${dry[@]}" --time "$MAX_AGE_DAYS" "$project" || true
          cargo-sweep sweep "''${dry[@]}" --maxsize "$MAX_SIZE" "$project" || true
          echo "swept $target ($before -> $(du -sh "$target" | cut -f1))"
        fi

        for fd in "''${fds[@]}"; do exec {fd}>&-; done
      done
    '';
  };
in
{
  home.packages = [ sweep ];

  systemd.user.services.cargo-target-sweep = {
    Unit.Description = "Prune stale and oversized Cargo target directories";
    Service = {
      Type = "oneshot";
      ExecStart = "${sweep}/bin/cargo-target-sweep";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.cargo-target-sweep = {
    Unit.Description = "Daily Cargo target directory prune";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
      Unit = "cargo-target-sweep.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
