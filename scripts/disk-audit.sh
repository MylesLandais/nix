#!/usr/bin/env bash
# Read-only disk space audit for Cerberus (and any NixOS host).
#
# Produces a full accounting of where disk space has gone, including the
# root-owned regions a plain user-level `du` silently skips. Makes no
# changes; see disk-reclaim.sh for the acting counterpart.
#
# Usage:
#   scripts/disk-audit.sh                 # audit /, text report to stdout
#   sudo scripts/disk-audit.sh            # same, but sees root-owned dirs
#   scripts/disk-audit.sh -m /mnt/data    # audit another mountpoint
#   scripts/disk-audit.sh -o report.txt   # tee report to a file
#   scripts/disk-audit.sh -q              # skip the slow whole-tree scans

set -euo pipefail

program="disk-audit"

die() {
  printf '%s: %s\n' "$program" "$*" >&2
  exit 1
}

mount_point=/
out_file=
quick=0
top_n=25

usage() {
  sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while getopts ':m:o:n:qh' opt; do
  case "$opt" in
    m) mount_point=$OPTARG ;;
    o) out_file=$OPTARG ;;
    n) top_n=$OPTARG ;;
    q) quick=1 ;;
    h) usage 0 ;;
    :) die "option -$OPTARG requires an argument" ;;
    \?) die "unknown option -$OPTARG (try -h)" ;;
  esac
done

[ -d "$mount_point" ] || die "not a directory: $mount_point"

if [ -n "$out_file" ]; then
  exec > >(tee "$out_file") 2>&1
fi

# du on a live root hits transient files and unreadable dirs constantly;
# those errors are noise, not findings. The unreadable dirs get their own
# section below so they are reported rather than silently dropped.
du_x() { du -x "$@" 2>/dev/null || true; }

human() { numfmt --to=iec --suffix=B "${1:-0}" 2>/dev/null || printf '%s' "${1:-0}"; }

rule() { printf '\n%s\n%s\n' "$1" "$(printf '=%.0s' $(seq 1 ${#1}))"; }

if [ "$(id -u)" -eq 0 ]; then
  privileged=1
else
  privileged=0
fi

printf '%s report - %s\n' "$program" "$(date -Is)"
printf 'host=%s mount=%s privileged=%s\n' "$(hostname)" "$mount_point" "$privileged"
[ "$privileged" -eq 1 ] || printf '\nNOTE: running unprivileged. Root-owned directories are NOT counted\n      in the du totals below. Re-run with sudo for a complete picture;\n      the "Unreadable" section quantifies exactly what is being missed.\n'

rule 'Capacity'
df -h "$mount_point"
printf '\n'
df -i "$mount_point"

rule 'Filesystem'
findmnt -no FSTYPE,SOURCE,OPTIONS "$mount_point" || true
fstype=$(findmnt -no FSTYPE "$mount_point" 2>/dev/null || echo unknown)
case "$fstype" in
  btrfs)
    printf '\nbtrfs detected: snapshots and unshared extents hide space from df/du.\n'
    btrfs filesystem usage "$mount_point" 2>/dev/null || true
    btrfs subvolume list "$mount_point" 2>/dev/null | head -"$top_n" || true
    ;;
  zfs)
    printf '\nzfs detected: check snapshot space below.\n'
    zfs list -o name,used,avail,refer,usedbysnapshots 2>/dev/null | head -"$top_n" || true
    ;;
esac

rule "Reconciliation (df vs du)"
# The single most useful number: how much space df sees that du cannot
# explain. A large gap means root-owned trees, deleted-but-open files,
# or filesystem-level overhead (reserved blocks, snapshots).
df_used_kb=$(df -P -k "$mount_point" | awk 'NR==2{print $3}')
du_used_kb=$(du_x -s -k "$mount_point" | awk '{print $1}')
gap_kb=$(( df_used_kb - du_used_kb ))
printf 'df reports used : %s\n' "$(human $(( df_used_kb * 1024 )))"
printf 'du can account  : %s\n' "$(human $(( du_used_kb * 1024 )))"
printf 'unaccounted gap : %s\n' "$(human $(( gap_kb * 1024 )))"
if [ "$gap_kb" -gt 10485760 ]; then
  printf '\n>> Gap exceeds 10 GiB. Investigate the Unreadable and Deleted sections.\n'
fi

rule "Top-level usage (depth 2, top $top_n)"
{ du_x -hd2 "$mount_point" | sort -rh | head -"$top_n"; } || true

rule 'Unreadable directories (du blind spots)'
# Anything listed here is missing from every du total in this report.
unreadable=$(find "$mount_point" -xdev -type d ! -readable -prune -print 2>/dev/null || true)
if [ -z "$unreadable" ]; then
  printf 'none - du totals above are complete.\n'
else
  { printf '%s\n' "$unreadable" | head -"$top_n"; } || true
  printf '\ntotal unreadable dirs: %s\n' "$(printf '%s\n' "$unreadable" | wc -l)"
  printf 'Re-run this script with sudo to size them.\n'
fi

rule 'Largest files (top 20)'
{ find "$mount_point" -xdev -type f -size +1G -printf '%s\t%p\n' 2>/dev/null \
  | sort -rn | head -20 \
  | while IFS=$'\t' read -r size path; do printf '%10s  %s\n' "$(human "$size")" "$path"; done
} || true

rule 'Deleted but held open (space not freed until process exits)'
total=0
found=0
for fd in /proc/[0-9]*/fd/*; do
  target=$(readlink "$fd" 2>/dev/null) || continue
  case "$target" in
    *'(deleted)'*) ;;
    *) continue ;;
  esac
  # memfd/shm live in RAM, not on the audited filesystem - exclude them
  # so this number reflects genuinely reclaimable disk.
  case "$target" in
    /memfd:*|/dev/shm/*) continue ;;
  esac
  size=$(stat -L -c %s "$fd" 2>/dev/null) || continue
  total=$(( total + size ))
  found=$(( found + 1 ))
  pid=${fd#/proc/}; pid=${pid%%/*}
  printf '%10s  pid=%-8s %s  %s\n' "$(human "$size")" "$pid" "$(cat "/proc/$pid/comm" 2>/dev/null || echo '?')" "$target"
done | { sort -rh | head -15; } || true
printf '\nheld-open total: %s across %s fds (restart those processes to reclaim)\n' "$(human "$total")" "$found"

rule 'Nix store'
if [ -d /nix/store ]; then
  printf 'store size      : %s\n' "$(du_x -sh /nix/store | cut -f1)"
  printf 'system generations:\n'
  nix-env --list-generations --profile /nix/var/nix/profiles/system 2>/dev/null | tail -10 || true
  printf '\ngarbage collectable (dry run):\n'
  nix-collect-garbage --dry-run 2>&1 | tail -5 || true

  # The check that matters most. A store can be almost entirely *reachable*
  # and still be mostly waste: every path here is pinned by some GC root, so
  # nix-collect-garbage will not touch a byte of it. On 2026-09-04 this was
  # 200 GiB against a 58 GiB live system -- two forgotten `nix build` result
  # symlinks under /tmp alone held 24 GiB of installer ISOs.
  #
  # Anything outside /nix/var/nix/profiles and ~/.local/state is suspect:
  # stale `result` links, abandoned direnv profiles, orphaned state dirs.
  printf '\nGC roots by closure size (excluding /proc):\n'
  nix-store --gc --print-roots 2>/dev/null \
    | grep -v '"/proc' \
    | sed 's/^"//; s/" -> / /' \
    | while read -r root target; do
        [ -e "$target" ] || continue
        size=$(nix path-info -S "$target" 2>/dev/null | awk '{print $NF}')
        [ -n "$size" ] || continue
        case "$root" in
          /nix/var/nix/profiles/*|/run/*|"$HOME"/.local/state/*) flag='   ' ;;
          *) flag=' ! ' ;;
        esac
        # Emit raw bytes as a leading sort key so the flag column cannot
        # skew the ordering, then strip it back off after sorting.
        printf '%s\t%s%12s  %s\n' "$size" "$flag" "$(human "$size")" "$root"
      done | { sort -k1 -rn | cut -f2-; } || true
  printf '\n( ! = root outside the system/user profile dirs -- likely a stale\n'
  printf '  result symlink or abandoned profile. Removing the symlink is enough;\n'
  printf '  the next GC then reclaims its closure. )\n'
fi

if [ "$quick" -eq 0 ]; then
  rule 'Regenerable build artifacts'
  # These cost only rebuild time to restore, so they are the safest
  # reclaim targets and are worth calling out separately from real data.
  for pat in target node_modules .venv __pycache__ .next dist .gradle .stack-work; do
    find "$mount_point" -xdev -maxdepth 8 -type d -name "$pat" -prune -print0 2>/dev/null \
      | du -x --files0-from=- -sb 2>/dev/null \
      | awk -v p="$pat" '{s+=$1; n++} END{ if (n) printf "%-16s %12s  (%d dirs)\n", p, sprintf("%.1f GiB", s/1073741824), n }'
  done

  rule 'Caches'
  for d in "$HOME/.cache" /var/cache /root/.cache; do
    [ -d "$d" ] || continue
    printf '\n%s:\n' "$d"
    du_x -hd1 "$d" | sort -rh | head -12
  done

  rule 'Root-owned files under home directories'
  # Services running as root that write into a user's home create files
  # the user cannot delete - a recurring cause of "I cleaned up but
  # nothing was freed".
  for h in /home/*; do
    [ -d "$h" ] || continue
    owner=$(stat -c %U "$h" 2>/dev/null) || continue
    find "$h" -xdev -maxdepth 6 -user root -type d -prune -print0 2>/dev/null \
      | du -x --files0-from=- -sh 2>/dev/null | sort -rh | head -10 \
      | sed "s|^|  |"
  done
fi

rule 'Container storage (docker / podman)'
# /var/lib/docker is mode 0710. An unprivileged `du /var` therefore reports a
# tiny number while omitting the whole container store - the most common cause
# of a large df-vs-du gap on a dev box. Ask the daemon instead of the filesystem.
for engine in docker podman; do
  command -v "$engine" >/dev/null 2>&1 || continue
  printf '\n-- %s --\n' "$engine"
  if ! "$engine" system df 2>/dev/null; then
    printf '  %s installed but daemon unreachable (need root or group membership)\n' "$engine"
    continue
  fi
  printf '\n  largest volumes:\n'
  "$engine" system df -v 2>/dev/null \
    | awk '/^Local Volumes space usage:/{f=1;next} /^Build cache/{f=0} f && NF>=3 && $1!="VOLUME"{print $NF"\t"$(NF-1)"\t"$1}' \
    | sort -h -r | head -15 \
    | awk -F'\t' '{printf "  %10s  links=%-4s %s\n", $1, $2, $3}'
done

rule 'Logs'
journalctl --disk-usage 2>/dev/null || true
{ du_x -hd1 /var/log 2>/dev/null | sort -rh | head -10; } || true

printf '\n%s: complete.\n' "$program"
