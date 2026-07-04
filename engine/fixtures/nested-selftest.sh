#!/bin/bash
# nested-selftest — full 2-level recursion e2e, ZERO LLM calls (mock-agent).
# Covers (rfc-nested §11 "smallest honest test" + extras):
#   1. single make -j2 builds whole tree: sentinels, dep order, call counts,
#      depth + MAXTIER command-line propagation
#   2. idempotent rerun: no agent calls, no artifact mtime churn
#   3. deep resume: rm ONE deep sentinel → parent stays lazy (completed
#      subtree not re-entered, rfc §7) → subtree make rebuilds ONLY that leaf,
#      siblings untouched (mtime)
#   4. failure bubble: grandchild check.sh exit 1 → parent exit ≠ 0, sentinel
#      absent → resume rebuilds only the failed leaf + downstream
#   5. depth cap: AGENTMAKE_MAXDEPTH=0 forces composite → leaf (no scaffold)
#   6. MAXFANOUT gate: plan wider than cap rejected, plan.json deleted
#   7. MAXTIER clamp: TIER=prd under MAXTIER=vague → vague row (build.mk rule)
#   8. observability: wfcheck recursion, progress/graph subtree rendering
#   9. id charset gate: metachar/traversal/non-kebab ids rejected (plan gate
#      + subtree helper) — ids splice into make+shell, LLM = trust boundary
set -euo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)      # engine/fixtures
ENGINE=$(cd "$DIR/.." && pwd)           # engine
EVALS=$(cd "$ENGINE/.." && pwd)/evals
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
fail() { echo "nested-selftest: FAIL — $1" >&2; exit 1; }
mt() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1"; }
pos() { grep -n "^build $1\$" "$MOCK_LOG" | head -1 | cut -d: -f1; }

export AGENT="$DIR/mock-agent"

mkproj() {  # mkproj <dir> — fixture root project (mock root plan keys off non-SUBTREE goal)
  mkdir -p "$1"
  printf '# nested fixture root goal\ntwo leaves plus one composite chunk.\n' > "$1/goal.md"
  printf 'GOAL ?= goal.md\ninclude %s/build.mk\n' "$ENGINE" > "$1/Makefile"
}

# ── 1. single make -j2 run builds the whole tree
P=$TMP/run1; mkproj "$P"
export MOCK_LOG="$TMP/mock1.log"
make -C "$P" -j2 all > "$TMP/run1.log" 2>&1 \
  || fail "make -j2 all exited non-zero:$(printf '\n'; tail -20 "$TMP/run1.log" | sed 's/^/  /')"
for s in leaf-one leaf-two comp; do
  [ -f "$P/build/$s.done" ] || fail "missing sentinel build/$s.done"
done
for s in sub-a sub-b sub-c; do
  [ -f "$P/src/comp/build/$s.done" ] || fail "missing deep sentinel src/comp/build/$s.done"
done
grep -q '^VERDICT: PASS$' "$P/build/report.md" || fail "parent verdict not PASS"
grep -q '^VERDICT: PASS$' "$P/src/comp/build/report.md" || fail "subtree verdict not PASS"
[ -x "$P/src/comp/check.sh" ] && [ -f "$P/src/comp/Makefile" ] || fail "subtree scaffold incomplete"

# dep order (positions in the shared append log; -j2 interleaves the rest)
[ "$(pos leaf-one)" -lt "$(pos leaf-two)" ] || fail "order: leaf-one !< leaf-two"
[ "$(pos leaf-one)" -lt "$(pos sub-a)" ]    || fail "order: leaf-one !< sub-a (comp deps leaf-one)"
[ "$(pos sub-a)" -lt "$(pos sub-b)" ]       || fail "order: sub-a !< sub-b"
[ "$(pos sub-b)" -lt "$(pos sub-c)" ]       || fail "order: sub-b !< sub-c"

# call census: one pipeline per level, no extra runs. 5 builds = 5 LEAVES —
# the composite itself is recursed, never handed to the build role.
[ "$(grep -c '^build '    "$MOCK_LOG")" -eq 5 ] || fail "expected 5 leaf builds, got $(grep -c '^build ' "$MOCK_LOG")"
[ "$(grep -c '^plan '     "$MOCK_LOG")" -eq 2 ] || fail "expected 2 plans (root + subtree)"
[ "$(grep -c '^review '   "$MOCK_LOG")" -eq 2 ] || fail "expected 2 reviews"

# depth + tier ceiling ride the $(MAKE) command line into the child
grep -q '^plan d=0$' "$MOCK_LOG" || fail "root plan not at depth 0"
grep -q '^plan d=1$' "$MOCK_LOG" || fail "subtree plan not at depth 1"
jq -e '.tier=="standard"' "$P/build/effort.json" > /dev/null || fail "root tier != standard default"
jq -e '.tier=="standard"' "$P/src/comp/build/effort.json" > /dev/null || fail "child did not inherit parent tier"

# ── 2. idempotent rerun: zero agent calls, zero mtime churn
snapshot() {
  for f in "$P"/build/*.done "$P"/build/report.md "$P"/src/comp/build/*.done "$P"/src/comp/build/report.md; do
    echo "$f $(mt "$f")"
  done
}
s1=$(snapshot); c1=$(wc -l < "$MOCK_LOG")
make -C "$P" all > /dev/null 2>&1 || fail "idempotent rerun failed"
[ "$(snapshot)" = "$s1" ] || fail "idempotent rerun touched artifacts"
[ "$(wc -l < "$MOCK_LOG")" -eq "$c1" ] || fail "idempotent rerun made agent calls"

# ── 3. deep resume: rm ONE deep sentinel
rm "$P/src/comp/build/sub-c.done"
# parent view: comp.done up to date against ITS prereqs — completed subtree is
# not re-entered (lazy by design, rfc §7; failure/interrupt re-entry is test 4)
make -C "$P" all > /dev/null 2>&1 || fail "parent rerun after deep rm failed"
[ ! -f "$P/src/comp/build/sub-c.done" ] || fail "parent re-entered completed subtree (should be lazy)"
# subtree == project: resume at the level that owns the sentinel
ma=$(mt "$P/src/comp/build/sub-a.done"); mb=$(mt "$P/src/comp/build/sub-b.done")
m1=$(mt "$P/build/leaf-one.done"); m2=$(mt "$P/build/leaf-two.done"); mc=$(mt "$P/build/comp.done")
c2=$(grep -c '^build ' "$MOCK_LOG")
make -C "$P/src/comp" all > /dev/null 2>&1 || fail "subtree resume failed"
[ -f "$P/src/comp/build/sub-c.done" ] || fail "sub-c.done not rebuilt"
[ "$(mt "$P/src/comp/build/sub-a.done")" = "$ma" ] || fail "resume rebuilt sub-a (sibling should be untouched)"
[ "$(mt "$P/src/comp/build/sub-b.done")" = "$mb" ] || fail "resume rebuilt sub-b (sibling should be untouched)"
[ "$(mt "$P/build/leaf-one.done")" = "$m1" ] || fail "resume touched parent leaf-one"
[ "$(mt "$P/build/leaf-two.done")" = "$m2" ] || fail "resume touched parent leaf-two"
[ "$(mt "$P/build/comp.done")" = "$mc" ] || fail "resume touched parent comp sentinel"
[ "$(grep -c '^build ' "$MOCK_LOG")" -eq $((c2 + 1)) ] || fail "resume made != 1 build call"
[ "$(grep '^build ' "$MOCK_LOG" | tail -1)" = "build sub-c" ] || fail "resume rebuilt wrong leaf"

# ── 4. failure bubble: grandchild check.sh exit 1 → bubbles N levels; resume rebuilds only failed leaf
P2=$TMP/run2; mkproj "$P2"
export MOCK_LOG="$TMP/mock2.log"
MOCK_FAIL_ID=sub-b make -C "$P2" -j2 all > "$TMP/run2.log" 2>&1 \
  && fail "broken grandchild check.sh did not bubble to parent exit"
[ ! -f "$P2/src/comp/build/sub-b.done" ] || fail "sub-b.done exists despite failing check"
[ ! -f "$P2/build/comp.done" ]   || fail "parent comp.done exists despite grandchild failure"
[ ! -f "$P2/build/report.md" ]   || fail "parent review ran despite failure"
[ -f "$P2/src/comp/build/sub-a.done" ] || fail "sub-a should have completed before the failure"
msa=$(mt "$P2/src/comp/build/sub-a.done"); ml1=$(mt "$P2/build/leaf-one.done")
make -C "$P2" -j2 all > "$TMP/run2b.log" 2>&1 || fail "resume after fix failed"
[ -f "$P2/build/comp.done" ] || fail "resume did not complete the subtree"
grep -q '^VERDICT: PASS$' "$P2/build/report.md" || fail "resume verdict not PASS"
[ "$(mt "$P2/src/comp/build/sub-a.done")" = "$msa" ] || fail "resume rebuilt sub-a"
[ "$(mt "$P2/build/leaf-one.done")" = "$ml1" ] || fail "resume rebuilt leaf-one"
grep -q '^build sub-b$' "$MOCK_LOG" || fail "resume did not rebuild sub-b"
[ "$(grep -c '^build sub-a$' "$MOCK_LOG")" -eq 1 ] || fail "sub-a built more than once across fail+resume"

# ── 5. depth cap: AGENTMAKE_MAXDEPTH=0 → AT_CAP forces composite to leaf
P3=$TMP/run3; mkproj "$P3"
export MOCK_LOG="$TMP/mock3.log"
make -C "$P3" -j2 AGENTMAKE_MAXDEPTH=0 all > "$TMP/run3.log" 2>&1 || fail "depth-cap run failed"
[ -f "$P3/build/comp.done" ] || fail "depth-cap: comp.done missing"
[ ! -f "$P3/src/comp/Makefile" ] || fail "depth cap did not force leaf (subtree scaffolded)"
grep -q '^build comp$' "$MOCK_LOG" || fail "comp not built as a leaf at depth cap"
[ "$(grep -c '^plan ' "$MOCK_LOG")" -eq 1 ] || fail "depth-cap run planned more than once"

# ── 6. MAXFANOUT gate: 3-component plan rejected at MAXFANOUT=2
P4=$TMP/run4; mkproj "$P4"
export MOCK_LOG="$TMP/mock4.log"
make -C "$P4" MAXFANOUT=2 all > "$TMP/run4.log" 2>&1 \
  && fail "MAXFANOUT=2 not enforced against 3-component plan"
[ ! -f "$P4/build/plan.json" ] || fail "plan.json survived failed fanout gate (.DELETE_ON_ERROR)"

# ── 7. MAXTIER clamp (build.mk effort rule): TIER=prd under MAXTIER=vague → vague row
mkdir -p "$TMP/clamp"; echo 'goal' > "$TMP/clamp/goal.md"
printf 'GOAL=goal.md\nB=build\nSRC=src\nAGENT=%s\ninclude %s\n' "$AGENT" "$ENGINE/build.mk" > "$TMP/clamp/Makefile"
( cd "$TMP/clamp" && make -s TIER=prd MAXTIER=vague build/effort.json )
jq -e '.tier=="vague" and .fanout=="2-3" and .review_depth=="smoke" and .model_hint=="small" and .thinking=="low"' "$TMP/clamp/build/effort.json" > /dev/null \
  || fail "MAXTIER=vague clamp: expected whole vague row, got: $(cat "$TMP/clamp/build/effort.json")"
rm -rf "$TMP/clamp/build"
( cd "$TMP/clamp" && make -s TIER=prd MAXTIER=prd build/effort.json )
jq -e '.tier=="prd" and .thinking=="high"' "$TMP/clamp/build/effort.json" > /dev/null \
  || fail "MAXTIER=prd clamp altered an in-bounds row: $(cat "$TMP/clamp/build/effort.json")"

# ── 8. observability over the nested run
"$EVALS/wfcheck" "$P" > /dev/null || fail "wfcheck failed on good nested run"
jq -e '(.checks[] | select(.name=="subtree:comp") | .pass) and .subtrees.comp.score == 1' \
  "$P/build/wfscore.json" > /dev/null || fail "wfcheck missing subtree:comp / drill-down map"
[ -f "$P/src/comp/build/wfscore.json" ] || fail "child wfscore.json missing"
# capture-then-grep: grep -q early-exit + pipefail would turn make's SIGPIPE into a false FAIL
grep -q 'sub-a.done'    <<<"$(make -s -C "$P" progress)" || fail "progress does not recurse into subtree"
grep -q 'subgraph comp' <<<"$(make -s -C "$P" graph)"    || fail "graph missing subtree subgraph"

# ── 9. id charset gate: hostile ids never reach the jq→makefile splice
P5=$TMP/run5; mkproj "$P5"
export MOCK_LOG="$TMP/mock5.log"
for bad in 'evil; rm -rf .' '../escape' 'a b' 'UPPER' '$(AGENT)'; do
  MOCK_BAD_ID="$bad" make -C "$P5" all > "$TMP/run5.log" 2>&1 \
    && fail "plan gate accepted id: $bad"
  [ ! -f "$P5/build/plan.json" ] || fail "plan.json survived id gate ($bad)"
done
# engine/subtree enforces the same boundary when invoked directly
if (cd "$P5" && "$ENGINE/subtree" '../up') > /dev/null 2>&1; then
  fail "subtree accepted traversal id"
fi

echo "nested-selftest: PASS (tree build, order, idempotence, deep resume, bubble+resume, depth cap, fanout gate, tier clamp, wfcheck/progress/graph recursion, id gate)"
