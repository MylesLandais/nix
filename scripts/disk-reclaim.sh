#!/usr/bin/env bash
# Reclaim disk space in tiers, safest first. Dry-run unless --apply.
#
# Tiers:
#   build     regenerable build output (target/, .venv, node_modules, __pycache__)
#   cache     package manager caches (uv, pip, npm, cargo registry)
#   models    HuggingFace / llama.cpp model caches (re-downloadable, slow)
#   nix       nix generations + store garbage collection
#   docker    dangling images, build cache, stopped containers (volumes only listed)
#   logs      journald vacuum
#
# Usage:
#   scripts/disk-reclaim.sh                      # dry run, all tiers
#   scripts/disk-reclaim.sh -t build,cache       # dry run, chosen tiers
#   scripts/disk-reclaim.sh -t build --apply     # actually delete
#   scripts/disk-reclaim.sh -t models -k qwen,gemma --apply   # keep matches
#
# Every tier prints what it would remove and the total, so a dry run is a
# usable report on its own.

set -euo pipefail

program="disk-reclaim"

die() {
  printf '%s: %s\n' "$program" "$*" >&2
  exit 1
}

apply=0
tiers=build,cache,models,nix,docker,logs
keep_pattern=
roots=${HOME}

usage() {
  sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --apply) apply=1; shift ;;
    -t|--tiers) tiers=${2:?} ; shift 2 ;;
    -k|--keep) keep_pattern=${2:?} ; shift 2 ;;
    -r|--roots) roots=${2:?} ; shift 2 ;;
    -h|--help) usage 0 ;;
    *) die "unknown argument: $1 (try -h)" ;;
  esac
done

freed_total=0

human() { numfmt --to=iec --suffix=B "${1:-0}" 2>/dev/null || printf '%s' "${1:-0}"; }

has_tier() { case ",$tiers," in *,"$1",*) return 0 ;; *) return 1 ;; esac; }

rule() { printf '\n== %s ==\n' "$1"; }

# Central choke point: every destructive action in this script goes through
# here, so --apply is the single switch between reporting and deleting.
act() {
  local path=$1 size
  size=$(du -xsb "$path" 2>/dev/null | awk '{print $1}') || size=0
  freed_total=$(( freed_total + size ))
  if [ "$apply" -eq 1 ]; then
    printf '  REMOVE %10s  %s\n' "$(human "$size")" "$path"
    rm -rf -- "$path"
  else
    printf '  would remove %10s  %s\n' "$(human "$size")" "$path"
  fi
}

# Keep patterns are comma-separated substrings matched case-insensitively
# against the path, so `-k qwen,gemma` protects those model dirs.
kept() {
  [ -n "$keep_pattern" ] || return 1
  local p
  IFS=, read -ra pats <<< "$keep_pattern"
  for p in "${pats[@]}"; do
    case "${1,,}" in *"${p,,}"*) return 0 ;; esac
  done
  return 1
}

printf '%s - mode=%s tiers=%s\n' "$program" "$([ "$apply" -eq 1 ] && echo APPLY || echo DRY-RUN)" "$tiers"
[ "$apply" -eq 1 ] || printf '(nothing will be deleted; re-run with --apply)\n'

if has_tier build; then
  rule 'Build artifacts'
  for pat in target .venv node_modules __pycache__ .next; do
    while IFS= read -r -d '' d; do
      # A target/ dir is only cargo output if a Cargo.toml sits beside it;
      # otherwise it may well be source code named "target".
      if [ "$pat" = target ] && [ ! -f "$(dirname "$d")/Cargo.toml" ]; then
        printf '  skip (no Cargo.toml)  %s\n' "$d"
        continue
      fi
      act "$d"
    done < <(find $roots -xdev -maxdepth 8 -type d -name "$pat" -prune -print0 2>/dev/null)
  done
fi

if has_tier cache; then
  rule 'Package caches'
  for d in "$HOME/.cache/uv" "$HOME/.cache/pip" "$HOME/.npm/_cacache" \
           "$HOME/.cache/yarn" "$HOME/.cargo/registry/cache" "$HOME/.cache/go-build"; do
    [ -d "$d" ] && act "$d"
  done
fi

if has_tier models; then
  rule 'Model caches'
  for base in "$HOME/.cache/huggingface/hub" "$HOME/.cache/llm/llama.cpp"; do
    [ -d "$base" ] || continue
    for d in "$base"/*; do
      [ -e "$d" ] || continue
      if kept "$d"; then
        printf '  KEEP   %10s  %s\n' "$(du -xsh "$d" 2>/dev/null | cut -f1)" "$d"
        continue
      fi
      # Root-owned model dirs are common when a service downloaded them;
      # flag rather than fail so the user knows to re-run under sudo.
      if [ ! -w "$d" ] && [ "$(id -u)" -ne 0 ]; then
        printf '  NEEDS-ROOT %7s  %s\n' "$(du -xsh "$d" 2>/dev/null | cut -f1)" "$d"
        continue
      fi
      act "$d"
    done
  done
fi

if has_tier nix; then
  rule 'Nix'
  # Order matters. `nix-collect-garbage -d` cannot free per-user profile
  # generations -- only `nix profile wipe-history` can -- so running the GC
  # alone leaves their closures pinned. That is exactly what happened on
  # 2026-09-02: a full GC freed 40 GiB and left 331 GiB behind, because 879
  # user-profile generations were still holding it.
  if [ "$apply" -eq 1 ]; then
    nix profile wipe-history || true
    sudo nix-collect-garbage -d
    sudo nix-store --optimise
  else
    nix profile history 2>/dev/null | grep -c '^Version' \
      | awk '{ if ($1 > 1) printf "  user profile generations to prune: %d\n", $1-1 }' || true
    nix-collect-garbage --dry-run 2>&1 | tail -5 || true
    printf '  would run: nix profile wipe-history\n'
    printf '  would run: sudo nix-collect-garbage -d && sudo nix-store --optimise\n'
  fi
fi

if has_tier podman || has_tier docker; then
  rule 'Containers (docker / podman)'
  for engine in docker podman; do
    command -v "$engine" >/dev/null 2>&1 || continue
    printf '\n-- %s --\n' "$engine"
    "$engine" system df 2>/dev/null || { printf '  daemon unreachable\n'; continue; }
    if [ "$apply" -eq 1 ]; then
      # Deliberately NOT --volumes: an unused volume is still real data
      # (a database, an object store) and deleting it is unrecoverable.
      # Prune images/containers/build cache only; volumes are listed for
      # the operator to remove by name.
      "$engine" system prune -af 2>/dev/null || true
      "$engine" builder prune -af 2>/dev/null || true
    else
      printf '  would run: %s system prune -af  (images, stopped containers, build cache)\n' "$engine"
      printf '  would run: %s builder prune -af\n' "$engine"
    fi
    printf '\n  UNUSED volumes (links=0) - review and remove by name, NOT pruned automatically:\n'
    "$engine" system df -v 2>/dev/null \
      | awk '/^Local Volumes space usage:/{f=1;next} /^Build cache/{f=0} f && NF>=3 && $1!="VOLUME" && $(NF-1)=="0"{print $NF"\t"$1}' \
      | sort -h -r | head -20 \
      | awk -F'\t' '{printf "    %10s  %s\n", $1, $2}'
    printf '    (remove with: %s volume rm <name>)\n' "$engine"
  done
fi

if has_tier logs; then
  rule 'Logs'
  journalctl --disk-usage 2>/dev/null || true
  if [ "$apply" -eq 1 ]; then
    sudo journalctl --vacuum-size=500M
  else
    printf '  would run: sudo journalctl --vacuum-size=500M\n'
  fi
fi

printf '\n%s: %s %s\n' "$program" \
  "$([ "$apply" -eq 1 ] && echo freed || echo 'would free')" "$(human "$freed_total")"
printf 'note: nix/docker/logs tiers are not included in that total.\n'
