#!/usr/bin/env bash
# Self-tests for the migration harness (M-002). They run against throwaway
# commits in a scratch clone, never in the real repository.
#
#   scripts/migration/selftest.sh <migration-binary> <scratch-dir> [host]
#
# The default host is kali-vm: its eval is fast, and host.isDesktop is only
# read by a dead bar module, so flipping it changes no derivation.
set -euo pipefail

MIGRATION=$1
SCRATCH=$2
HOST=${3:-kali-vm}
SRC=$(git rev-parse --show-toplevel)
CLONE="$SCRATCH/selftest-clone"
pass=0
fails=()

ok() {
  echo "PASS: $*"
  pass=$((pass + 1))
}
bad() {
  echo "FAIL: $*"
  fails+=("$*")
}

rm -rf "$CLONE"
git clone -q "$SRC" "$CLONE"
cd "$CLONE"
git config commit.gpgsign false
git config user.email selftest@localhost
git config user.name selftest
# Optional: test on top of uncommitted source changes (e.g. when commits are
# blocked), given as a patch file.
if [[ -n ${SELFTEST_PATCH:-} ]]; then
  git apply "$SELFTEST_PATCH"
  git commit -qam "selftest: apply SELFTEST_PATCH"
fi
# Self-tests need the harness docs even when the source HEAD predates them.
if [[ ! -f docs/migration/tasks.yaml ]]; then
  mkdir -p docs/migration
  cp "$SRC"/docs/migration/{tasks.yaml,volatile.txt,frozen.txt} docs/migration/
  git add docs/migration && git commit -qm "selftest: harness docs"
fi
cat >>docs/migration/tasks.yaml <<'EOF'
  - id: SELFTEST
    title: harness self-test
    phase: 0
    depends_on: []
    policy: pure_refactor
    hosts: []
EOF
git commit -qam "selftest: task"
M() { "$MIGRATION" "$@" --repo "$CLONE"; }
BASE=$(git rev-parse HEAD)

# 1. Capturing the same revision twice gives byte-identical JSON.
M capture --rev "$BASE" --hosts "$HOST" >/dev/null
cache=$(dirname "$(find .migration/cache -name "host-$HOST.json" -path "*$BASE*")")
cp "$cache/host-$HOST.json" "$SCRATCH/first.json"
cp "$cache/flake.json" "$SCRATCH/first-flake.json"
rm -rf "$cache"
M capture --rev "$BASE" --hosts "$HOST" >/dev/null
if cmp -s "$SCRATCH/first.json" "$cache/host-$HOST.json" && cmp -s "$SCRATCH/first-flake.json" "$cache/flake.json"; then
  ok "1 capture is deterministic"
else
  bad "1 capture differs between two runs of the same rev"
fi

# 2. A comment-only change gives no B or C difference.
cfg=modules/hosts/$HOST/configuration.nix
[[ -f $cfg ]] || cfg=$(git grep -l "flake.modules.nixos" -- 'modules/hosts/*' | head -1)
sed -i '1a # selftest: comment-only change' "$cfg"
git commit -qam "selftest: comment"
C2=$(git rev-parse HEAD)
if M verify --task SELFTEST --rev "$C2" --against "$BASE" --hosts "$HOST" >"$SCRATCH/t2.txt" 2>&1; then
  ok "2 comment-only change verifies clean"
else
  bad "2 comment-only change was flagged: $(head -5 "$SCRATCH/t2.txt")"
fi

# 3. An option flip that changes no derivation is still caught by layer C.
sed -i -E '0,/isDesktop = (true|false);/{s/isDesktop = true;/isDesktop = __FLIP__;/; s/isDesktop = false;/isDesktop = true;/; s/__FLIP__/false/}' "$cfg"
git commit -qam "selftest: flip host.isDesktop"
C3=$(git rev-parse HEAD)
M verify --task SELFTEST --rev "$C3" --against "$C2" --hosts "$HOST" >"$SCRATCH/t3.txt" 2>&1 || true
r=$(jq -c --arg h "$HOST" '{drv: .hosts[$h].drv_changed, c: [.hosts[$h].C[].path], ok: .within_allowed}' .migration/reports/SELFTEST.json)
if [[ $(jq -r .drv <<<"$r") == false && $(jq -r .ok <<<"$r") == false ]] && jq -e '.c | any(test("^host/"))' <<<"$r" >/dev/null; then
  ok "3 drv-neutral option flip caught by layer C ($r)"
else
  bad "3 option flip not caught as expected: $r"
fi
git revert --no-edit HEAD >/dev/null

# 4. A renamed module is caught by layer A.
mod=$(sed -nE 's/.*flake\.modules\.nixos\.([A-Za-z0-9]+) =.*/\1/p' "$cfg" | head -1)
git grep -lw "modules.nixos.$mod" -- modules | xargs sed -i -E "s/modules\.nixos\.$mod\b/modules.nixos.${mod}Renamed/g"
git commit -qam "selftest: rename module"
C4=$(git rev-parse HEAD)
M verify --task SELFTEST --rev "$C4" --against "$C2" --hosts "$HOST" >"$SCRATCH/t4.txt" 2>&1 || true
if jq -e '(.within_allowed | not) and (.problems | any(test("registry")))' .migration/reports/SELFTEST.json >/dev/null &&
  jq -e --arg h "$HOST" '.hosts[$h].drv_changed | not' .migration/reports/SELFTEST.json >/dev/null; then
  ok "4 module rename caught by layer A (B unchanged)"
else
  bad "4 rename not caught: $(jq -c .problems .migration/reports/SELFTEST.json)"
fi

# 5. Dirty worktree with bare HEAD, and unknown revisions, are refused.
echo "# dirty" >>"$cfg"
if M capture --hosts "$HOST" >/dev/null 2>&1; then bad "5a dirty HEAD accepted"; else ok "5a dirty HEAD refused"; fi
if M capture --rev deadbeefdeadbeef --hosts "$HOST" >/dev/null 2>&1; then bad "5b unknown rev accepted"; else ok "5b unknown rev refused"; fi

# 6. --rev evaluates that revision, not the worktree. The worktree now carries
#    a drv-changing edit; capturing C2 explicitly must match C2's clean capture.
git checkout -q "$cfg"
sed -i -E 's/isDesktop = (true|false);/isDesktop = \1; environment.etc."selftest-worktree".text = "x";/' "$cfg"
c2cache=$(dirname "$(find .migration/cache -name "host-$HOST.json" -path "*$C2*")")
cp "$c2cache/host-$HOST.json" "$SCRATCH/c2.json"
rm -rf "$c2cache"
M capture --rev "$C2" --hosts "$HOST" >/dev/null
if cmp -s "$SCRATCH/c2.json" "$c2cache/host-$HOST.json" && ! grep -q selftest-worktree "$c2cache/host-$HOST.json"; then
  ok "6 --rev ignores the worktree"
else
  bad "6 capture of an explicit rev picked up worktree changes"
fi
git checkout -q "$cfg"

# 7. A real content change that layer C cannot see (same package name and
#    version, different script text) must fail the content-equivalence proof.
git checkout -q "$C2" -- .
envpk=$(git grep -l 'writeShellScriptBin "helium-profile-guard"' -- modules | head -1)
sed -i 's|exec ${pkgs.python3}/bin/python3|exec ${pkgs.python3}/bin/python3 -B|' "$envpk"
git commit -qam "selftest: change helium-profile-guard text"
C7=$(git rev-parse HEAD)
M verify --task SELFTEST --rev "$C7" --against "$C2" --hosts "$HOST" >"$SCRATCH/t7.txt" 2>&1 || true
if jq -e --arg h "$HOST" '(.within_allowed | not) and .hosts[$h].drv_changed and (.hosts[$h].C | length == 0)
    and (.hosts[$h].content_equivalence.equivalent == false)' .migration/reports/SELFTEST.json >/dev/null; then
  ok "7 hidden content change rejected by content equivalence"
else
  bad "7 hidden content change not rejected: $(jq -c --arg h "$HOST" '{ok: .within_allowed, c: (.hosts[$h].C | length), eq: .hosts[$h].content_equivalence.equivalent}' .migration/reports/SELFTEST.json)"
fi

echo
echo "selftest: $pass passed, ${#fails[@]} failed"
[[ ${#fails[@]} -eq 0 ]]
