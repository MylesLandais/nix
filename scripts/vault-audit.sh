#!/usr/bin/env bash
# Read-only health report for an Obsidian vault (default ~/Vault).
#
# Reports the things that actually rot a vault over time: unreferenced
# attachments, broken links, root-level clutter, and duplicate note names.
# Makes no changes - every finding is something for a human to decide on.
#
# Usage:
#   scripts/vault-audit.sh              # audit ~/Vault
#   scripts/vault-audit.sh -v ~/Notes   # audit another vault
#   scripts/vault-audit.sh -o rep.txt   # tee to a file

set -euo pipefail

program="vault-audit"

die() {
  printf '%s: %s\n' "$program" "$*" >&2
  exit 1
}

vault="${HOME}/Vault"
out_file=
top_n=20

while getopts ':v:o:n:h' opt; do
  case "$opt" in
    v) vault=$OPTARG ;;
    o) out_file=$OPTARG ;;
    n) top_n=$OPTARG ;;
    h) sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    :) die "option -$OPTARG requires an argument" ;;
    \?) die "unknown option -$OPTARG (try -h)" ;;
  esac
done

[ -d "$vault" ] || die "not a directory: $vault"
cd "$vault"

if [ -n "$out_file" ]; then
  exec > >(tee "$out_file") 2>&1
fi

rule() { printf '\n%s\n%s\n' "$1" "$(printf '=%.0s' $(seq 1 ${#1}))"; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

printf '%s - %s\n' "$program" "$(date -Is)"
printf 'vault=%s\n' "$vault"

rule 'Size'
printf 'total size   : %s\n' "$(du -sh . 2>/dev/null | cut -f1)"
printf 'total files  : %s\n' "$(find . -type f -not -path './.git/*' | wc -l)"
printf 'notes (.md)  : %s\n' "$(find . -type f -name '*.md' | wc -l)"
printf 'folders      : %s\n' "$(find . -mindepth 1 -type d -not -path './.git*' | wc -l)"

rule 'Root clutter'
# A vault can legitimately be flat, so this is a signal rather than a verdict.
# What matters is loose *attachments* at root, which belong beside no note.
printf 'loose files at root : %s\n' "$(find . -maxdepth 1 -type f | wc -l)"
printf '  markdown          : %s\n' "$(find . -maxdepth 1 -type f -name '*.md' | wc -l)"
printf '  images            : %s\n' "$(find . -maxdepth 1 -type f \
    \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.gif' \) | wc -l)"
printf '  other             : %s\n' "$(find . -maxdepth 1 -type f \
    -not -name '*.md' -not -iname '*.png' -not -iname '*.jpg' -not -iname '*.jpeg' \
    -not -iname '*.webp' -not -iname '*.gif' | wc -l)"

# Collect every link target once; both link styles, basename-normalised.
# Obsidian resolves [[note]] by shortest unique name regardless of folder, so
# comparing basenames is the correct test for "is this referenced at all".
# Strip fenced code blocks and inline code first. Bash's `[[ $x -eq 1 ]]` test
# syntax is textually identical to a wikilink, so scanning raw markdown reports
# thousands of shell snippets as broken links.
find . -type f -name '*.md' -not -path './.git/*' -print0 2>/dev/null \
  | xargs -0 -r awk '
      FNR==1 { infence=0 }
      /^[[:space:]]*(```|~~~)/ { infence = !infence; next }
      !infence { gsub(/`[^`]*`/, ""); print }
    ' 2>/dev/null \
  | grep -oE '(!?\[\[[^]]+\]\]|\]\([^)]+\))' 2>/dev/null \
  | sed -E 's/^!?\[\[//; s/\]\]$//; s/^\]\(//; s/\)$//' \
  | sed 's/|.*$//; s/#.*$//' \
  | sed 's|.*/||' \
  | sed 's/%20/ /g' \
  | sed 's/[[:space:]]*$//' \
  | sort -u > "$work/refs"

rule 'Unreferenced attachments'
# Attachments nothing links to are the safest thing to archive: no note breaks.
# NOTE: "unreferenced" means no link points at it - not that it is garbage. A
# reference library (PDFs, papers) is legitimately unreferenced. Review before
# acting on anything here.
#
# Matching is done with a single awk pass over an in-memory hash rather than a
# grep per file: the vault has ~100k link targets and ~3k attachments, so the
# naive nested loop is O(n*m) and does not finish.
find . -type f -not -path './.git/*' -not -path './.obsidian/*' \
  \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \
     -o -iname '*.gif' -o -iname '*.pdf' -o -iname '*.mp4' -o -iname '*.m4a' \) \
  -printf '%s\t%p\n' 2>/dev/null > "$work/attachments"

awk -F'\t' '
  NR==FNR { ref[$0]=1; next }
  {
    path=$2
    n=split(path, parts, "/")
    base=parts[n]
    stem=base
    sub(/\.[^.]*$/, "", stem)
    if (!(base in ref) && !(stem in ref)) print $1 "\t" path
  }
' "$work/refs" "$work/attachments" > "$work/orphans"

total=$(wc -l < "$work/attachments")
orphans=$(wc -l < "$work/orphans")
bytes=$(awk -F'\t' '{s+=$1} END{print s+0}' "$work/orphans")

printf 'attachments total : %s\n' "$total"
printf 'unreferenced      : %s (%s)\n' "$orphans" \
  "$(numfmt --to=iec --suffix=B "$bytes" 2>/dev/null || echo "${bytes}B")"
if [ "$orphans" -gt 0 ]; then
  printf '\nlargest unreferenced:\n'
  { sort -t"$(printf '\t')" -k1 -rn "$work/orphans" || true; } | head -"$top_n" \
    | while IFS=$'\t' read -r size path; do
        printf '%10s  %s\n' "$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "$size")" "$path"
      done
fi

rule 'Broken links (approximate)'
# A link whose target resolves to no file and no note name in the vault.
#
# APPROXIMATE by nature. Markdown that documents shell code contains `[[ $x ]]`
# test syntax that is textually identical to a wikilink. Fenced blocks are
# stripped above, but indented (unfenced) code still leaks, so targets carrying
# shell metacharacters are filtered out below. Expect residual noise; treat this
# as a list to skim, not a defect count.
find . -type f -not -path './.git/*' -printf '%f\n' 2>/dev/null | sort -u > "$work/names"
find . -type f -name '*.md' -printf '%f\n' 2>/dev/null | sed 's/\.md$//' | sort -u >> "$work/names"
sort -u -o "$work/names" "$work/names"

awk '
  NR==FNR { name[$0]=1; next }
  {
    t=$0
    if (t == "") next
    if (t ~ /^https?:/ || t ~ /^mailto:/ || t ~ /^#/) next
    # Shell/regex fragments that survived code-block stripping.
    if (t ~ /[$"`*\\^{}=<>]/) next
    if (t ~ /^[[:space:]]*$/ || t ~ /^[-.]/) next
    # Bare uuids and hex digests are ids pasted into notes, not link targets.
    if (t ~ /^[0-9a-f]{8}-[0-9a-f]{4}-/ || t ~ /^[0-9a-f]{16,}$/) next
    n=split(t, parts, "/")
    base=parts[n]
    stem=base
    sub(/\.[^.]*$/, "", stem)
    if (!(base in name) && !(stem in name)) print t
  }
' "$work/names" "$work/refs" > "$work/broken"

printf 'distinct link targets : %s\n' "$(wc -l < "$work/refs")"
printf 'unresolved            : %s\n' "$(wc -l < "$work/broken")"
if [ -s "$work/broken" ]; then
  head -"$top_n" "$work/broken" | sed 's/^/  /'
fi

rule 'Duplicate note names'
# Obsidian resolves [[link]] by name; two notes sharing a name makes every
# link to that name ambiguous and silently resolve to only one of them.
find . -type f -name '*.md' -not -path './.git/*' -printf '%f\n' 2>/dev/null \
  | sort | uniq -d > "$work/dupes" || true
printf 'duplicated names : %s\n' "$(wc -l < "$work/dupes")"
if [ -s "$work/dupes" ]; then
  { head -"$top_n" "$work/dupes" || true; } | while IFS= read -r name; do
    printf '  %s\n' "$name"
    find . -type f -name "$name" -not -path './.git/*' -printf '      %p\n' 2>/dev/null
  done
fi

rule 'Largest files'
{ find . -type f -not -path './.git/*' -printf '%s\t%p\n' 2>/dev/null \
  | sort -rn || true; } | head -"$top_n" \
  | while IFS=$'\t' read -r size path; do
      printf '%10s  %s\n' "$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || echo "$size")" "$path"
    done

printf '\n%s: complete. Nothing was modified.\n' "$program"
