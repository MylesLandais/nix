# shellcheck shell=bash
# Content equivalence of two derivations (sourced by migration.sh).
#
#   drv_equiv OLD.drv NEW.drv  -> prints a JSON report, returns 0 if equivalent
#
# Two derivations are equivalent when they build the same thing up to the
# names of their inputs. The derivation graphs are walked from the top:
#
# 1. Differing inputs are paired by name (e.g. home-manager-path on both
#    sides), recursively, and every pair gets a unique index.
# 2. Every pair's output paths are replaced by @p<index>-<output>@ on both
#    sides, globally, so text that embeds store paths from anywhere in the
#    differing subgraph compares equal.
# 3. A pair whose definitions are identical under that substitution differs
#    only through inputs that are themselves checked. Any other pair is a root:
#    its own definition changed (for example, a list merged in another order).
#    Roots are built, old and new, and their output trees must match file for
#    file (type, mode, symlink target, content) under the same substitution.
#
# Unpaired or ambiguous inputs make the pair unprovable, which counts as not
# equivalent. Builds that would fetch more than MIGRATION_MAX_FETCH_MIB
# (default 2048) are not attempted and are also unprovable.

DRV_EQ_DIR=""

_drv_json() { # drv path -> cached `nix derivation show` value
  local f
  f="$DRV_EQ_DIR/json-$(basename "$1")"
  [[ -s $f ]] || nix derivation show "$1" 2>/dev/null | jq '.derivations | to_entries[0].value' >"$f"
  cat "$f"
}

_drv_name() { # /nix/store/<hash>-<name>.drv -> <name>
  basename "$1" .drv | cut -d- -f2-
}

# Output basenames of a drv: JSON {output: basename}
_drv_outs() { _drv_json "$1" | jq -c '.outputs | map_values(.path)'; }

# Pair the input drvs that differ between A and B by name.
# Prints JSON {pairs: [[a,b],…], unpaired: [names]}
_drv_pairs() {
  _drv_json "$1" | jq '.inputs.drvs | keys' >"$DRV_EQ_DIR/ka.json"
  _drv_json "$2" | jq '.inputs.drvs | keys' >"$DRV_EQ_DIR/kb.json"
  _drv_json "$1" | jq '.inputs.srcs' >"$DRV_EQ_DIR/sa-src.json"
  _drv_json "$2" | jq '.inputs.srcs' >"$DRV_EQ_DIR/sb-src.json"
  jq -n --slurpfile ka "$DRV_EQ_DIR/ka.json" --slurpfile kb "$DRV_EQ_DIR/kb.json" \
    --slurpfile sa "$DRV_EQ_DIR/sa-src.json" --slurpfile sb "$DRV_EQ_DIR/sb-src.json" '
    $ka[0] as $a | $kb[0] as $b |
    def nm: sub("^[a-z0-9]{32}-"; "") | sub("\\.drv$"; "");
    ($a - $b) as $oa | ($b - $a) as $ob
    | ([$oa[] | nm] + [$ob[] | nm] | unique) as $names
    | (reduce $names[] as $n ({pairs: [], unpaired: []};
        ([$oa[] | select(nm == $n)]) as $x | ([$ob[] | select(nm == $n)]) as $y
        | if ($x | length) == 1 and ($y | length) == 1
          then .pairs += [[$x[0], $y[0]]]
          else .unpaired += [$n] end)) as $d
    # Input sources (builtins.toFile, path literals) that differ, paired by name.
    | ($sa[0] - $sb[0]) as $xa | ($sb[0] - $sa[0]) as $xb
    | ([$xa[] | nm] + [$xb[] | nm] | unique) as $snames
    | reduce $snames[] as $n ($d + {srcpairs: []};
        ([$xa[] | select(nm == $n)]) as $x | ([$xb[] | select(nm == $n)]) as $y
        | if ($x | length) == 1 and ($y | length) == 1
          then .srcpairs += [[$x[0], $y[0]]]
          else .unpaired += ["src:" + $n] end)'
}

_apply_subst() { # json-text subst-json -> substituted text (literal replace)
  local f
  f=$(mktemp -p "$DRV_EQ_DIR" subst.XXXX)
  echo "$2" >"$f"
  jq -Rs . <<<"$1" | jq -r --slurpfile s "$f" 'reduce $s[0][] as $r (.; split($r[0]) | join($r[1]))'
}

# Manifest of a built output with substitutions applied: one line per entry
# (type, mode, path, symlink target or content hash). Regular files are hashed
# in bulk; only files that contain a substituted store path are rewritten first.
# docs/migration/order-insensitive.txt entries: "<drv-name glob>:<path>[:mode]".
# Modes (default "tokens"):
#   tokens    sorted whitespace-separated tokens
#   kv        like tokens, but only when every key (text before "=") is unique;
#             otherwise the file stays byte-exact
#   bootspec  boot.json with .kernelParams sorted under the same kv rule
# A path of "." means a single-file output.
_order_insensitive() { # drv-name -> "path mode" lines
  [[ -f ${MIG:-}/order-insensitive.txt ]] || return 0
  local glob path mode
  grep -v -e '^#' -e '^$' "$MIG/order-insensitive.txt" | while IFS=: read -r glob path mode; do
    # shellcheck disable=SC2053
    [[ $1 == $glob ]] && echo "$path ${mode:-tokens}"
  done
}

_normalize() { # file mode -> normalized content on stdout
  case $2 in
  tokens) tr -s ' \t\n' '\n' <"$1" | sort ;;
  kv)
    if tr -s ' \t\n' '\n' <"$1" | grep -v '^$' | cut -d= -f1 | sort | uniq -d | grep -q .; then
      cat "$1"
    else
      tr -s ' \t\n' '\n' <"$1" | sort
    fi
    ;;
  bootspec)
    jq -S 'walk(if type == "object" and has("kernelParams")
                  and ((.kernelParams | map(split("=")[0]) | unique | length) == (.kernelParams | length))
                then .kernelParams |= sort else . end)' "$1"
    ;;
  *) cat "$1" ;;
  esac
}

_manifest() { # store-path subst-json [drv-name]
  local root=$1 subst=$2 name=${3:-} sed_args=() r pat
  pat=$(mktemp -p "$DRV_EQ_DIR" patterns.XXXX) # per call: diff <(…) <(…) runs two at once
  jq -r '.[][0]' <<<"$subst" >"$pat"
  while read -r r; do sed_args+=(-e "s|$(jq -r '.[0]' <<<"$r")|$(jq -r '.[1]' <<<"$r")|g"); done < <(jq -c '.[]' <<<"$subst")
  if [[ ! -d $root ]]; then
    local mode
    mode=$(_order_insensitive "$name" | awk '$1 == "." {print $2}' | head -1)
    if [[ -n $mode ]]; then
      printf 'file %s (normalized %s)\n' "$(_normalize "$root" "$mode" | sed "${sed_args[@]}" | sha256sum | cut -c1-64)" "$mode"
    else
      printf 'file %s\n' "$(sed "${sed_args[@]}" "$root" | sha256sum | cut -c1-64)"
    fi
    return
  fi
  (
    cd "$root"
    # Non-regular entries; symlink targets come from %l.
    find . ! -type f -printf '%y %m %p -> %l\n'
    # Regular files without substituted paths: hash as-is, in bulk.
    find . -type f -print0 | xargs -0 -r grep -LZF -f "$pat" -- 2>/dev/null |
      xargs -0 -r sha256sum -- | awk '{h=$1; $1=""; sub(/^ /, ""); print "f " $0 " " h}'
    # Files that mention a substituted path: rewrite, then hash.
    find . -type f -print0 | xargs -0 -r grep -lZF -f "$pat" -- 2>/dev/null |
      while IFS= read -r -d '' f; do printf 'f %s %s\n' "$f" "$(sed "${sed_args[@]}" "$f" | sha256sum | cut -c1-64)"; done
    # Modes of regular files.
    find . -type f -printf 'm %m %p\n'
    # Order-insensitive files: hash of sorted tokens, overriding the lines above.
    if [[ -n $name ]]; then
      _order_insensitive "$name" | while read -r f mode; do
        [[ $f != . && -f $f ]] && printf 'f %s %s (sorted)\n' "$f" "$(_normalize "$f" "$mode" | sed "${sed_args[@]}" | sha256sum | cut -c1-64)"
      done
    fi
  ) | sed "${sed_args[@]}" | sort | awk '
    # Keep the "(sorted)" line for a path in place of its byte-exact line.
    { line[NR] = $0; split($0, w, " "); if ($NF == "(sorted)") sorted[w[2]] = 1 }
    END { for (i = 1; i <= NR; i++) { split(line[i], w, " ");
            if (w[1] == "f" && sorted[w[2]] && line[i] !~ /\(sorted\)$/) continue; print line[i] } }'
}

_fetch_mib() { # drv… -> MiB the build would download
  nix build --dry-run --no-link "${@/%/^*}" 2>&1 | sed -nE 's/.*\(([0-9.]+) MiB download.*/\1/p' | awk '{s+=$1} END {printf "%d\n", s}'
}

# Root check: build both and compare manifests.
_root_equal() { # a b substA substB -> JSON result
  local a=$1 b=$2 sa=$3 sb=$4 mib out o pa pb
  mib=$(_fetch_mib "$a" "$b")
  if ((mib > ${MIGRATION_MAX_FETCH_MIB:-2048})); then
    jq -nc --arg a "$a" --arg b "$b" --argjson mib "$mib" '{a: $a, b: $b, equal: false, reason: "would fetch \($mib) MiB"}'
    return
  fi
  if ! nix build --no-link "$a^*" "$b^*" >"$DRV_EQ_DIR/build.log" 2>&1; then
    jq -nc --arg a "$a" --arg b "$b" --arg log "$(tail -5 "$DRV_EQ_DIR/build.log")" '{a: $a, b: $b, equal: false, reason: "build failed", log: $log}'
    return
  fi
  out=true
  for o in $(_drv_outs "$a" | jq -r 'keys[]'); do
    pa=/nix/store/$(_drv_outs "$a" | jq -r --arg o "$o" '.[$o]')
    pb=/nix/store/$(_drv_outs "$b" | jq -r --arg o "$o" '.[$o]')
    local nm
    nm=$(_drv_name "$a")
    if ! diff -q <(_manifest "$pa" "$sa" "$nm") <(_manifest "$pb" "$sb" "$nm") >/dev/null; then
      diff <(_manifest "$pa" "$sa" "$nm") <(_manifest "$pb" "$sb" "$nm") | head -20 >"$DRV_EQ_DIR/mdiff-$o"
      out=false
    fi
  done
  jq -nc --arg a "$a" --arg b "$b" --argjson eq "$out" --arg d "$(cat "$DRV_EQ_DIR"/mdiff-* 2>/dev/null)" \
    '{a: $a, b: $b, equal: $eq} + (if $eq then {} else {manifest_diff: $d} end)'
  rm -f "$DRV_EQ_DIR"/mdiff-*
}

# Pass 1: collect every differing pair reachable from the top pair, with a
# unique index. Unpaired differing inputs are recorded as unprovable.
_drv_collect() { # a b
  local a=$1 b=$2 key pairs p
  [[ $a == "$b" ]] && return
  key="$(basename "$a")~$(basename "$b")"
  grep -qxF "$key" "$DRV_EQ_DIR/seen" 2>/dev/null && return
  echo "$key" >>"$DRV_EQ_DIR/seen"
  echo "$a $b" >>"$DRV_EQ_DIR/pairs"
  pairs=$(_drv_pairs "$a" "$b")
  if [[ $(jq '.unpaired | length' <<<"$pairs") -gt 0 ]]; then
    jq -nc --arg a "$a" --arg b "$b" --argjson u "$(jq -c .unpaired <<<"$pairs")" \
      '{a: $a, b: $b, equal: false, reason: "unpaired differing inputs", unpaired: $u}' >>"$DRV_EQ_DIR/results"
  fi
  jq -r '.srcpairs[] | "/nix/store/\(.[0]) /nix/store/\(.[1])"' <<<"$pairs" >>"$DRV_EQ_DIR/srcpairs"
  while read -r p; do
    [[ -z $p ]] && continue
    _drv_collect "/nix/store/$(jq -r '.[0]' <<<"$p")" "/nix/store/$(jq -r '.[1]' <<<"$p")"
  done < <(jq -c '.pairs[]' <<<"$pairs")
}

# Global substitution maps: each pair's outputs map to @p<index>-<output>@ on
# both sides. Written to $DRV_EQ_DIR/subst-a.json and subst-b.json.
_drv_global_subst() {
  local n=0 a b
  : >"$DRV_EQ_DIR/sa.jsonl"
  : >"$DRV_EQ_DIR/sb.jsonl"
  while read -r a b; do
    n=$((n + 1))
    _drv_outs "$a" | jq -c --arg n "$n" 'to_entries[] | [.value, "@p\($n)-\(.key)@"]' >>"$DRV_EQ_DIR/sa.jsonl"
    _drv_outs "$b" | jq -c --arg n "$n" 'to_entries[] | [.value, "@p\($n)-\(.key)@"]' >>"$DRV_EQ_DIR/sb.jsonl"
  done <"$DRV_EQ_DIR/pairs"
  sort -u "$DRV_EQ_DIR/srcpairs" | while read -r a b; do
    n=$((n + 1))
    jq -nc --arg p "$(basename "$a")" --arg n "$n" '[$p, "@s\($n)@"]' >>"$DRV_EQ_DIR/sa.jsonl"
    jq -nc --arg p "$(basename "$b")" --arg n "$n" '[$p, "@s\($n)@"]' >>"$DRV_EQ_DIR/sb.jsonl"
  done
  jq -s . "$DRV_EQ_DIR/sa.jsonl" >"$DRV_EQ_DIR/subst-a.json"
  jq -s . "$DRV_EQ_DIR/sb.jsonl" >"$DRV_EQ_DIR/subst-b.json"
}

# Pass 2: a pair whose definitions are equal under the global maps differs
# only through inputs that are themselves checked; any other pair is a root
# and is built and compared.
_drv_judge() {
  local a b ca cb
  while read -r a b; do
    ca=$(_apply_subst "$(_drv_json "$a" | jq -c 'del(.outputs) | .inputs.drvs |= (keys | map(sub("^[a-z0-9]{32}-"; "")) | sort)')" "$(cat "$DRV_EQ_DIR/subst-a.json")")
    cb=$(_apply_subst "$(_drv_json "$b" | jq -c 'del(.outputs) | .inputs.drvs |= (keys | map(sub("^[a-z0-9]{32}-"; "")) | sort)')" "$(cat "$DRV_EQ_DIR/subst-b.json")")
    if [[ $ca != "$cb" ]]; then
      _root_equal "$a" "$b" "$(cat "$DRV_EQ_DIR/subst-a.json")" "$(cat "$DRV_EQ_DIR/subst-b.json")" >>"$DRV_EQ_DIR/results"
    fi
  done <"$DRV_EQ_DIR/pairs"
  sort -u "$DRV_EQ_DIR/srcpairs" | while read -r a b; do
    if diff -q <(_manifest "$a" "$(cat "$DRV_EQ_DIR/subst-a.json")") <(_manifest "$b" "$(cat "$DRV_EQ_DIR/subst-b.json")") >/dev/null; then
      jq -nc --arg a "$a" --arg b "$b" '{a: $a, b: $b, equal: true, kind: "src"}'
    else
      jq -nc --arg a "$a" --arg b "$b" --arg d "$(diff <(_manifest "$a" "$(cat "$DRV_EQ_DIR/subst-a.json")") <(_manifest "$b" "$(cat "$DRV_EQ_DIR/subst-b.json")") | head -20)" \
        '{a: $a, b: $b, equal: false, kind: "src", manifest_diff: $d}'
    fi
  done >>"$DRV_EQ_DIR/results"
}

drv_equiv() { # old.drv new.drv
  DRV_EQ_DIR=$(mktemp -d)
  : >"$DRV_EQ_DIR/results"
  : >"$DRV_EQ_DIR/pairs"
  : >"$DRV_EQ_DIR/srcpairs"
  _drv_collect "$1" "$2"
  # Unprovable already: don't build anything.
  if [[ ! -s $DRV_EQ_DIR/results ]]; then
    _drv_global_subst
    _drv_judge
  fi
  local report
  report=$(jq -s '{roots: ., equivalent: (length > 0 and all(.equal))}' "$DRV_EQ_DIR/results")
  rm -rf "$DRV_EQ_DIR"
  echo "$report"
  [[ $(jq -r .equivalent <<<"$report") == true ]]
}
