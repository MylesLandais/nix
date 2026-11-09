# shellcheck shell=bash
# Migration harness CLI. Packaged by modules/flake/migration.nix, which
# sets HARNESS_FLAKE (a store copy of snapshot.nix wrapped as a flake).
# Policies and the task contract are documented in docs/migration/README.md.
set -euo pipefail

usage() {
  cat <<'EOF'
migration capture   [--rev REV] [--hosts a,b|all] [--no-flake]
migration verify    --task ID [--rev REV] [--against REV] [--hosts a,b|all] [--write-evidence]
migration audit     [--rev REV] [--hosts a,b|all]
migration inventory [--rev REV]
common: [--repo DIR]   (default: the git toplevel of $PWD)

REV defaults to HEAD; --against defaults to REV^. Snapshots are cached in
<repo>/.migration/cache/<harness>/<sha>/ and are always taken from the
committed tree at that sha, never from the worktree.
EOF
}

die() {
  echo "migration: $*" >&2
  exit 2
}
log() { echo "migration: $*" >&2; }

[[ $# -ge 1 ]] || {
  usage
  exit 2
}
MODE=$1
shift

REPO="" REV="HEAD" AGAINST="" HOSTS="" TASK="" NO_FLAKE=0 WRITE_EVIDENCE=0
while [[ $# -gt 0 ]]; do
  case $1 in
  --repo) REPO=$2; shift 2 ;;
  --rev) REV=$2; shift 2 ;;
  --against) AGAINST=$2; shift 2 ;;
  --hosts) HOSTS=$2; shift 2 ;;
  --task) TASK=$2; shift 2 ;;
  --no-flake) NO_FLAKE=1; shift ;;
  --write-evidence) WRITE_EVIDENCE=1; shift ;;
  -h | --help) usage; exit 0 ;;
  *) die "unknown argument: $1" ;;
  esac
done

TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT

REPO=${REPO:-$(git rev-parse --show-toplevel)}
REPO=$(cd "$REPO" && pwd)
MIG="$REPO/docs/migration"
HARNESS_ID=$(basename "$HARNESS_FLAKE" | cut -c1-12)
CACHE="$REPO/.migration/cache/$HARNESS_ID"
NARHASH=$(nix hash path --sri "$HARNESS_FLAKE")

# --- revisions --------------------------------------------------------------

resolve() {
  local r
  r=$(git -C "$REPO" rev-parse --verify --quiet "$1^{commit}") || die "unknown revision: $1"
  echo "$r"
}

# A bare `HEAD` with uncommitted changes almost certainly means "check my edits",
# which a rev snapshot cannot see. Refuse instead of silently ignoring them.
refuse_dirty_head() {
  if [[ $1 == HEAD ]] && [[ -n $(git -C "$REPO" status --porcelain --untracked-files=no -- . ':!.migration') ]]; then
    die "worktree has uncommitted changes; commit them (snapshots read the committed tree) or pass --rev explicitly"
  fi
}

# --- capture ----------------------------------------------------------------

nix_snapshot() { # sha selector-expr
  nix eval --json --option warn-dirty false --expr \
    "((builtins.getFlake \"path:$HARNESS_FLAKE?narHash=$NARHASH\").lib { flakeRef = \"git+file://$REPO?rev=$1\"; })$2"
}

check_rev() { # sha
  local got
  got=$(nix_snapshot "$1" ".meta.rev" 2>/dev/null | jq -r .)
  [[ $got == "$1" ]] || die "evaluated rev '$got' does not match requested $1"
}

all_hosts() { nix_snapshot "$1" ".meta.hosts" 2>/dev/null | jq -r '.[]'; }

capture_one() { # sha name(flake|host) -> path of cached json
  local sha=$1 what=$2 dir="$CACHE/$1" out sel
  mkdir -p "$dir"
  if [[ $what == flake ]]; then out="$dir/flake.json" sel=".flake"; else out="$dir/host-$what.json" sel=".host \"$what\""; fi
  if [[ ! -s $out ]]; then
    log "capturing $what @ ${sha:0:12}"
    if ! nix_snapshot "$sha" "$sel" 2>"$out.log" | jq -S . >"$out.tmp"; then
      rm -f "$out.tmp"
      tail -20 "$out.log" >&2
      die "evaluation of $what @ ${sha:0:12} failed (log: $out.log)"
    fi
    mv "$out.tmp" "$out"
  fi
  echo "$out"
}

host_list() { # sha spec
  if [[ -z $2 || $2 == all ]]; then all_hosts "$1"; else tr ',' '\n' <<<"$2"; fi
}

# Layer A extras that come from the git tree rather than evaluation.
path_imports() { # sha -> JSON array of "file: text"
  # Module references only: "${self}/modules/…" strings and ../ paths to .nix
  # files. Data files read with readFile/importJSON are not imports.
  git -C "$REPO" grep -nE '"\$\{(inputs\.)?self\}/modules/|(import |[[:space:]\[(])\.\./[A-Za-z0-9_./-]+\.nix' "$1" -- 'modules/*.nix' 'modules/**/*.nix' |
    sed -E "s/^$1://; s/^([^:]+):[0-9]+:[[:space:]]*/\1: /" | sort | jq -R . | jq -s .
}

capture() { # sha hosts-spec noflake
  local sha=$1 h
  check_rev "$sha"
  mkdir -p "$CACHE/$sha"
  [[ $3 == 1 ]] || capture_one "$sha" flake >/dev/null
  path_imports "$sha" >"$CACHE/$sha/path-imports.json"
  while read -r h; do capture_one "$sha" "$h" >/dev/null; done < <(host_list "$sha" "$2")
}

# --- comparison helpers -------------------------------------------------------

# Flatten JSON to {"a/b/c": "<json leaf>"}; arrays are compared whole.
# shellcheck disable=SC2016 # jq program, not shell
FLAT='def flat($p): if type == "object" and length > 0
        then to_entries | map(.key as $k | .value | flat($p + [$k])) | add
        else {($p | join("/")): tojson} end;
      flat([])'

flat_diff() { # fileA fileB jq-path -> JSON [{path, before, after}]
  jq -n --slurpfile a "$1" --slurpfile b "$2" "
    (\$a[0] | $3 // {} | $FLAT) as \$x | (\$b[0] | $3 // {} | $FLAT) as \$y
    | [(\$x + \$y) | keys[] | select(\$x[.] != \$y[.]) | {path: ., before: \$x[.], after: \$y[.]}]"
}

task_field() { # yq expression on the task entry
  yq -o=json ".tasks[] | select(.id == \"$TASK\") | $1" "$MIG/tasks.yaml"
}

# glob match of "host:path" against the task's allowed_changes
allowed() { # host path
  local g
  while read -r g; do
    [[ -z $g ]] && continue
    # shellcheck disable=SC2053
    [[ "$1:$2" == $g ]] && return 0
  done <<<"$ALLOWED"
  return 1
}

volatile() { # host path — known per-commit noise, see docs/migration/volatile.txt
  local g
  [[ -f $MIG/volatile.txt ]] || return 1
  while read -r g; do
    [[ -z $g || $g == \#* ]] && continue
    # shellcheck disable=SC2053
    [[ "$1:$2" == $g ]] && return 0
  done <"$MIG/volatile.txt"
  return 1
}

frozen_touched() { # base sha -> changed files under frozen globs
  [[ -f $MIG/frozen.txt ]] || return 0
  local f g
  while read -r f; do
    while read -r g; do
      [[ -z $g || $g == \#* ]] && continue
      # shellcheck disable=SC2053
      [[ $f == $g ]] && echo "$f" && break
    done <"$MIG/frozen.txt"
  done < <(git -C "$REPO" diff --name-only "$1" "$2")
}

nixdiff_summary() { # drvA drvB
  nix-diff --color never --line-oriented "$1" "$2" 2>&1 | head -60 | cut -c1-300 | head -c 8000 || true
}

# --- verify -----------------------------------------------------------------

verify() { # base sha hosts-spec -> writes $REPORT, returns 0 if within policy
  local base=$1 sha=$2 spec=$3 fail=0 h
  POLICY=$(task_field '.policy' | jq -r .)
  [[ $POLICY != null ]] || die "task $TASK not found in $MIG/tasks.yaml"
  ALLOWED=$(task_field '.allowed_changes // [] | .[]' | jq -r .)
  local contract registry_add registry_remove allow_frozen
  contract=$(task_field '.contract // [] | .[]' | jq -r .)
  registry_add=$(task_field '.registry.add // [] | .[]' | jq -r .)
  registry_remove=$(task_field '.registry.remove // [] | .[]' | jq -r .)
  allow_frozen=$(task_field '.allow_frozen // false' | jq -r .)
  [[ -z $spec ]] && spec=$(task_field '.hosts // [] | join(",")' | jq -r .)

  local hosts
  hosts=$( (host_list "$base" "$spec"; host_list "$sha" "$spec") | sort -u)
  capture "$base" "$(paste -sd, <<<"$hosts")" 0
  capture "$sha" "$(paste -sd, <<<"$hosts")" 0

  local fa="$CACHE/$base/flake.json" fb="$CACHE/$sha/flake.json" problems=()

  # Layer A: registry
  local reg_diff name
  reg_diff=$(flat_diff "$fa" "$fb" '.A.registry | map_values(map({(.): true}) | add // {})')
  while read -r name; do
    [[ -z $name ]] && continue
    local short=${name#*/} ns=${name%%/*} change
    # The public aliases mirror their registry namespace.
    case $ns in nixosModules) ns=nixos ;; homeManagerModules) ns=homeManager ;; esac
    name="$ns/$short"
    change=$(jq -r --arg p "$name" '.[] | select(.path == $p) | if .after == null then "remove" else "add" end' <<<"$reg_diff")
    if [[ $change == add ]] && ! grep -qxF "$short" <<<"$registry_add" && ! grep -qxF "${name%%/*}.$short" <<<"$registry_add"; then
      problems+=("A: registry gained undeclared $name"); fail=1
    fi
    if [[ $change == remove ]] && ! grep -qxF "$short" <<<"$registry_remove" && ! grep -qxF "${name%%/*}.$short" <<<"$registry_remove"; then
      problems+=("A: registry lost undeclared $name"); fail=1
    fi
  done < <(jq -r '.[].path' <<<"$reg_diff")
  if git -C "$REPO" cat-file -e "$sha:docs/migration/registry.json" 2>/dev/null; then
    if ! diff <(git -C "$REPO" show "$sha:docs/migration/registry.json" | jq -S .) <(jq -S .A.registry "$fb") >/dev/null; then
      problems+=("A: captured registry differs from docs/migration/registry.json at ${sha:0:12}"); fail=1
    fi
  fi

  # Layer A: output tree (registry-backed paths are judged above)
  local out_diff p
  out_diff=$(flat_diff "$fa" "$fb" '.A.outputs')
  while read -r p; do
    [[ -z $p ]] && continue
    case $p in modules/* | nixosModules/* | homeManagerModules/*) continue ;; esac
    local ok=0 g
    while read -r g; do
      # shellcheck disable=SC2053
      [[ -n $g && $p == $g ]] && ok=1
    done <<<"$contract"
    [[ $ok == 1 ]] || { problems+=("A: flake output changed outside contract: $p"); fail=1; }
  done < <(jq -r '.[].path' <<<"$out_diff")

  # Layer A: path imports may only go down
  local pi_a pi_b
  pi_a=$(jq length "$CACHE/$base/path-imports.json")
  pi_b=$(jq length "$CACHE/$sha/path-imports.json")
  local pi_allow
  pi_allow=$(task_field '.path_imports_allow // 0' | jq -r .)
  if ((pi_b > pi_a + pi_allow)); then
    problems+=("A: path-based imports increased $pi_a -> $pi_b (task allows +$pi_allow)")
    fail=1
  fi

  # Frozen paths
  local frozen
  frozen=$(frozen_touched "$base" "$sha")
  if [[ -n $frozen && $allow_frozen != true ]]; then
    problems+=("frozen paths touched: $(paste -sd' ' <<<"$frozen")")
    fail=1
  fi

  # Layer B (flake-level)
  local fb_diff
  fb_diff=$(flat_diff "$fa" "$fb" '.B')
  while read -r p; do
    [[ -z $p ]] && continue
    volatile flake "$p" && continue
    if [[ $POLICY == behavior_change ]] && allowed flake "$p"; then continue; fi
    local ok=0 g
    # Declared contract globs cover flake-level outputs under any policy.
    while read -r g; do
      # shellcheck disable=SC2053
      [[ -n $g && $p == $g ]] && ok=1
    done <<<"$contract"
    [[ $ok == 1 ]] || { problems+=("B: flake drv changed: $p"); fail=1; }
  done < <(jq -r '.[].path' <<<"$fb_diff")

  # Layers B + C per host
  local hosts_json="{}"
  while read -r h; do
    [[ -z $h ]] && continue
    local ha="$CACHE/$base/host-$h.json" hb="$CACHE/$sha/host-$h.json"
    local cdiff bdiff drv_changed unexpected="[]" nd="" equiv=""
    cdiff=$(flat_diff "$ha" "$hb" '.C')
    bdiff=$(flat_diff "$ha" "$hb" '.B')
    drv_changed=$([[ $(jq length <<<"$bdiff") -gt 0 ]] && echo true || echo false)
    local c_paths cp
    c_paths=$(jq -r '.[].path' <<<"$cdiff")
    local real_c=0
    while read -r cp; do
      [[ -z $cp ]] && continue
      volatile "$h" "$cp" && continue
      real_c=1
      if [[ $POLICY == behavior_change ]] && allowed "$h" "$cp"; then continue; fi
      unexpected=$(jq --arg p "$cp" '. + [$p]' <<<"$unexpected")
    done <<<"$c_paths"
    if [[ $drv_changed == true ]]; then
      nd=$(nixdiff_summary "$(jq -r .B.toplevel "$ha")" "$(jq -r .B.toplevel "$hb")")
      if [[ $POLICY != behavior_change ]]; then
        # A drv change whose only C trace is volatile noise is tolerated (and
        # recorded). Otherwise, with no layer-C change, the drvs may still be
        # content-equivalent (e.g. a list merged in another order): prove it by
        # building the root derivations (drv-equiv.sh). Anything else stops.
        if [[ $real_c == 0 ]] && volatile "$h" "B/toplevel"; then
          :
        elif [[ $real_c == 0 ]]; then
          log "$h: drv changed without layer-C change; checking content equivalence"
          if equiv=$(drv_equiv "$(jq -r .B.toplevel "$ha")" "$(jq -r .B.toplevel "$hb")"); then
            log "$h: content-equivalent ($(jq '.roots | length' <<<"$equiv") root derivation(s))"
          else
            problems+=("B: $h toplevel drv changed and is not provably content-equivalent: $(jq -c '[.roots[] | select(.equal | not) | {a: (.a | sub("/nix/store/[a-z0-9]{32}-"; "")), reason, manifest_diff}]' <<<"$equiv" | head -c 600)")
            fail=1
          fi
        else
          problems+=("B: $h toplevel drv changed under $POLICY"); fail=1
        fi
      elif ! allowed "$h" "B/*" && [[ $real_c == 0 ]] && ! volatile "$h" "B/toplevel"; then
        # No layer-C change explains it: it must be content-equivalent.
        log "$h: drv changed without layer-C change; checking content equivalence"
        if equiv=$(drv_equiv "$(jq -r .B.toplevel "$ha")" "$(jq -r .B.toplevel "$hb")"); then
          log "$h: content-equivalent ($(jq '.roots | length' <<<"$equiv") root derivation(s))"
        else
          problems+=("B: $h drv changed, no layer-C change explains it, and it is not provably content-equivalent"); fail=1
        fi
      fi
    fi
    if [[ $(jq length <<<"$unexpected") -gt 0 ]]; then
      problems+=("C: $h has $(jq length <<<"$unexpected") change(s) outside policy: $(jq -r '.[:8] | join(", ")' <<<"$unexpected")")
      fail=1
    fi
    # Large diffs go through files: --argjson would exceed ARG_MAX.
    echo "$cdiff" >"$TMPD/c.json"
    echo "$bdiff" >"$TMPD/b.json"
    echo "$unexpected" >"$TMPD/u.json"
    echo "$hosts_json" >"$TMPD/hosts.json"
    hosts_json=$(jq --arg h "$h" --slurpfile c "$TMPD/c.json" --slurpfile b "$TMPD/b.json" --slurpfile u "$TMPD/u.json" \
      --arg nd "$nd" --argjson dc "$drv_changed" --slurpfile eq <(echo "${equiv:-null}") \
      '. + {($h): {drv_changed: $dc, B: $b[0], C: $c[0], unexpected: $u[0], content_equivalence: $eq[0], nix_diff_summary: ($nd | split("\n"))}}' "$TMPD/hosts.json")
  done <<<"$hosts"

  echo "$reg_diff" >"$TMPD/reg.json"
  echo "$out_diff" >"$TMPD/out.json"
  echo "$fb_diff" >"$TMPD/fbd.json"
  echo "$hosts_json" >"$TMPD/hosts.json"
  REPORT=$(jq -n --arg task "$TASK" --arg policy "$POLICY" --arg base "$base" --arg rev "$sha" \
    --slurpfile reg "$TMPD/reg.json" --slurpfile out "$TMPD/out.json" --slurpfile fbd "$TMPD/fbd.json" \
    --slurpfile hosts "$TMPD/hosts.json" --argjson ok "$([[ $fail == 0 ]] && echo true || echo false)" \
    --arg problems "$(printf '%s\n' "${problems[@]+"${problems[@]}"}")" \
    --arg harness "$HARNESS_ID" \
    '{task: $task, policy: $policy, harness: $harness, base: $base, rev: $rev,
      A: {registry: $reg[0], outputs: $out[0]}, B_flake: $fbd[0], hosts: $hosts[0],
      problems: ($problems | split("\n") | map(select(. != ""))), within_allowed: $ok}')
  return $fail
}

report_summary() {
  jq -r '"task \(.task) [\(.policy)] \(.base[:12])..\(.rev[:12]): " + (if .within_allowed then "OK" else "FAIL" end),
    (.problems[] | "  ✗ " + .),
    (.hosts | to_entries[] | "  \(.key): drv \(if .value.drv_changed then "changed" else "same" end), C changes \(.value.C | length)")' <<<"$REPORT"
}

# --- audit ------------------------------------------------------------------

audit() { # sha hosts-spec
  local sha=$1 base fail=0 h
  base=$(resolve migration/baseline)
  local hosts
  hosts=$( (host_list "$base" "$2"; host_list "$sha" "$2") | sort -u)
  capture "$base" "$(paste -sd, <<<"$hosts")" 0
  capture "$sha" "$(paste -sd, <<<"$hosts")" 0
  # Everything any committed evidence file accounted for.
  local ev
  ev=$(git -C "$REPO" ls-tree -r --name-only "$sha" -- docs/migration/evidence/ |
    while read -r f; do git -C "$REPO" show "$sha:$f"; done | jq -s '{
      c: [.[] | .hosts | to_entries[] | .key as $h | .value.C[] | "\($h):\(.path)"],
      b: [.[] | .hosts | to_entries[] | select(.value.drv_changed) | .key],
      reg: [.[] | .A.registry[] | .path],
      out: [.[] | .A.outputs[] | .path],
      bflake: [.[] | .B_flake[] | .path]}')
  while read -r h; do
    [[ -z $h ]] && continue
    local ha="$CACHE/$base/host-$h.json" hb="$CACHE/$sha/host-$h.json" cp
    while read -r cp; do
      [[ -z $cp ]] && continue
      volatile "$h" "$cp" && continue
      jq -e --arg k "$h:$cp" '.c | index($k)' <<<"$ev" >/dev/null || { echo "unaccounted: $h C $cp"; fail=1; }
    done < <(flat_diff "$ha" "$hb" '.C' | jq -r '.[].path')
    if [[ $(jq -r .B.toplevel "$ha") != $(jq -r .B.toplevel "$hb") ]] && ! jq -e --arg h "$h" '.b | index($h)' <<<"$ev" >/dev/null && ! volatile "$h" B/toplevel; then
      echo "unaccounted: $h toplevel drv changed and no evidence records it"
      fail=1
    fi
  done <<<"$hosts"
  local p
  while read -r p; do
    [[ -z $p ]] && continue
    jq -e --arg k "$p" '(.reg + .out) | index($k)' <<<"$ev" >/dev/null || { echo "unaccounted: A $p"; fail=1; }
  done < <(flat_diff "$CACHE/$base/flake.json" "$CACHE/$sha/flake.json" '.A.outputs' | jq -r '.[].path'; flat_diff "$CACHE/$base/flake.json" "$CACHE/$sha/flake.json" '.A.registry | map_values(map({(.): true}) | add // {})' | jq -r '.[].path')
  while read -r p; do
    [[ -z $p ]] && continue
    volatile flake "$p" && continue
    jq -e --arg k "$p" '.bflake | index($k)' <<<"$ev" >/dev/null || { echo "unaccounted: flake B $p"; fail=1; }
  done < <(flat_diff "$CACHE/$base/flake.json" "$CACHE/$sha/flake.json" '.B' | jq -r '.[].path')
  [[ $fail == 0 ]] && echo "audit ${base:0:12}..${sha:0:12}: every difference is accounted for"
  return $fail
}

# --- inventory --------------------------------------------------------------

# Every module file wired in by path, with its import sites and class.
# The class is propagated through the import graph from the home-manager
# roots: a file imported (transitively) only from HM roots is homeManager,
# only from elsewhere is nixos, from both is "both".
HM_ROOTS='modules/_home.nix modules/hosts/cerberus/_home.nix modules/profiles/_server-home.nix'
inventory() { # sha
  local edges
  edges=$(inventory_edges "$1")
  if [[ -n ${INVENTORY_EDGES:-} ]]; then
    echo "$edges"
    return
  fi
  jq --arg roots "$HM_ROOTS" "$INVENTORY_CLASSIFY" <<<"$edges"
}

inventory_edges() { # sha -> JSON array of {target, file, line, hmsite}
  git -C "$REPO" grep -nE '"\$\{(inputs\.)?self\}/modules/[^"]+"|\.\.?/[A-Za-z0-9_./-]+' "$1" -- 'modules/*.nix' 'modules/**/*.nix' |
    sed -E "s/^$1://" | while IFS=: read -r file line text; do
    grep -oE '"\$\{(inputs\.)?self\}/modules/[^"]+"|\.\.?/[A-Za-z0-9_./-]+' <<<"$text" | while read -r ref; do
      local target
      if [[ $ref == \"* ]]; then
        target=$(sed -E 's/^"\$\{(inputs\.)?self\}\///; s/"$//' <<<"$ref")
      else
        target=$(realpath -m --relative-to="$REPO" "$REPO/$(dirname "$file")/$ref")
      fi
      if git -C "$REPO" cat-file -e "$1:$target/default.nix" 2>/dev/null; then target="$target/default.nix"; fi
      [[ $target == *.nix ]] || continue
      git -C "$REPO" cat-file -e "$1:$target" 2>/dev/null || continue
      # Sites inside homeModules = [ … ] lists (host default.nix) are HM roots.
      local hm=0
      # HM references on the line itself: `flake.modules.homeManager.x = import …`,
      # let-bound home module paths (homeNix, serverHome, …).
      if grep -qE 'homeManager|homeNix|serverHome|homeModules|sharedModules' <<<"$text"; then hm=1; fi
      if [[ $hm == 0 ]] && git -C "$REPO" show "$1:$file" | sed -n "1,$((line - 1))p" | tac | awk '/\]/{exit} /homeModules|sharedModules|home-manager( =|\.users)/{f=1; exit} END{exit !f}'; then hm=1; fi
      printf '%s\t%s\t%s\t%s\n' "$target" "$file" "$line" "$hm"
    done
  done | sort -u | jq -R 'split("\t") | {target: .[0], file: .[1], line: .[2], hmsite: (.[3] == "1")}' | jq -s .
}

# shellcheck disable=SC2016 # jq program
INVENTORY_CLASSIFY='
      . as $edges
      | ($roots | split(" ")) as $roots
      # class of each file: seed HM roots + HM sites, then propagate to a fixpoint
      | ($edges | map(select(.hmsite) | .target) + $roots | unique) as $hmseed
      | def step($hm): ($hm + [$edges[] | select(.file as $f | $hm | index($f)) | .target]) | unique;
        def fix($hm): step($hm) as $n | if ($n | length) == ($hm | length) then $hm else fix($n) end;
      fix($hmseed) as $hm
      | ($edges | map(select((.hmsite | not) and (.file as $f | ($hm | index($f)) | not)) | .target) | unique) as $nixdirect
      | def nstep($n): ($n + [$edges[] | select((.hmsite | not) and (.file as $f | $n | index($f))) | .target]) | unique;
        def nfix($n): nstep($n) as $m | if ($m | length) == ($n | length) then $n else nfix($m) end;
      nfix($nixdirect) as $nix
      | $edges | group_by(.target) | map({
          module: .[0].target,
          imported_by: map("\(.file):\(.line)"),
          class: (.[0].target as $t | if ($hm | index($t)) and ($nix | index($t)) then "both"
                  elif ($hm | index($t)) then "homeManager" else "nixos" end)
        })'


# --- main -------------------------------------------------------------------

case $MODE in
capture)
  refuse_dirty_head "$REV"
  SHA=$(resolve "$REV")
  capture "$SHA" "${HOSTS:-all}" "$NO_FLAKE"
  echo "$CACHE/$SHA"
  ;;
verify)
  [[ -n $TASK ]] || die "verify needs --task"
  refuse_dirty_head "$REV"
  SHA=$(resolve "$REV")
  BASE=$(resolve "${AGAINST:-$SHA^}")
  rc=0
  verify "$BASE" "$SHA" "$HOSTS" || rc=$?
  report_summary
  mkdir -p "$REPO/.migration/reports"
  echo "$REPORT" >"$REPO/.migration/reports/$TASK.json"
  if [[ $WRITE_EVIDENCE == 1 ]]; then
    mkdir -p "$MIG/evidence"
    jq -S . <<<"$REPORT" >"$MIG/evidence/$TASK.json"
    log "evidence written to docs/migration/evidence/$TASK.json"
  fi
  exit $rc
  ;;
audit)
  refuse_dirty_head "$REV"
  audit "$(resolve "$REV")" "${HOSTS:-all}"
  ;;
inventory)
  inventory "$(resolve "$REV")"
  ;;
*)
  usage
  exit 2
  ;;
esac
