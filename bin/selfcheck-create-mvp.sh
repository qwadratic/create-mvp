#!/usr/bin/env bash
# selfcheck: bin/create-mvp — mock runtime ONLY, zero LLM calls.
#   1 full pipeline + wfcheck   2 --dry posture       3 slug injection gate
#   4 --resume continues        5 --tier override     6 --board round-trip
#   7 progress passthrough
set -euo pipefail
DIR=$(cd "$(dirname "$0")" && pwd)
CLI=$DIR/create-mvp
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }
cd "$tmp"

# 1 ── full pipeline (mock plan includes a composite -> exercises nesting too)
"$CLI" --runtime mock "game of life, make it look alive" > run.txt 2>&1 \
  || { cat run.txt >&2; fail "full mock run exited nonzero"; }
d=game-of-life-make-it-look-alive
grep -q 'VERDICT: PASS' "$d/build/report.md"            || fail "no review verdict"
grep -q 'wfcheck: PASS' run.txt                          || fail "no wfcheck score in output"
grep -q "created -> ./$d" run.txt                         || fail "no artifact census"
[ "$(cat "$d/goal.md")" = "game of life, make it look alive" ] || fail "goal.md not verbatim"
echo "PASS 1 full pipeline + wfcheck"

# 2 ── --dry: classify+plan only, posture printed, nothing built
"$CLI" --dry --runtime mock --dir dry-run "a pomodoro timer, keyboard only" > dry.txt 2>&1 \
  || { cat dry.txt >&2; fail "--dry exited nonzero"; }
[ -f dry-run/build/plan.json ]   || fail "dry: no plan.json"
[ ! -f dry-run/build/report.md ] || fail "dry: review ran"
[ ! -d dry-run/src ]             || fail "dry: build agents fired"
grep -q 'tier=standard' dry.txt  || fail "dry: no posture line"
grep -q 'composite' dry.txt      || fail "dry: composite not marked in tree"
echo "PASS 2 --dry"

# 3 ── injection: metachars charset-gated out of the slug, goal.md verbatim,
#      nothing executed, nothing lands outside cwd
evil='$(rm -rf /tmp/create-mvp-pwned) ../../etc/passwd `x` "q"'
before=$(ls -d */ | sort)
"$CLI" --dry --runtime mock "$evil" > evil.txt 2>&1 \
  || { cat evil.txt >&2; fail "evil goal run failed"; }
new=$(comm -13 <(printf '%s\n' "$before") <(ls -d */ | sort)); new=${new%/}
[ "$(printf '%s\n' "$new" | wc -l | tr -d ' ')" = 1 ] || fail "injection: unexpected dirs: $new"
case $new in ''|*[!a-z0-9-]*) fail "slug charset breached: '$new'" ;; esac
[ "$(cat "$new/goal.md")" = "$evil" ] || fail "evil goal.md not verbatim"
[ ! -e /tmp/create-mvp-pwned ]              || fail "injection EXECUTED"
grep -q 'rm -rf' "$new/Makefile" && fail "goal text leaked into Makefile"
"$CLI" --dry --runtime mock '!!!' >/dev/null 2>&1 && fail "empty slug accepted"
echo "PASS 3 slug injection gated (dir: $new)"

# 4 ── --resume: finishes the dry run without replanning
plan_mtime=$(stat -f %m dry-run/build/plan.json 2>/dev/null || stat -c %Y dry-run/build/plan.json)
"$CLI" --resume dry-run --runtime mock > resume.txt 2>&1 \
  || { cat resume.txt >&2; fail "--resume exited nonzero"; }
grep -q 'VERDICT: PASS' dry-run/build/report.md || fail "resume did not finish the run"
now=$(stat -f %m dry-run/build/plan.json 2>/dev/null || stat -c %Y dry-run/build/plan.json)
[ "$plan_mtime" = "$now" ] || fail "resume replanned (plan.json mtime changed)"
echo "PASS 4 --resume"

# 5 ── --tier: classifier bypassed, override survives the run
"$CLI" --dry --runtime mock --tier prd --dir tiered "tiny thing" >/dev/null 2>&1 \
  || fail "--tier run failed"
[ "$(jq -r .tier tiered/build/effort.json)" = prd ] || fail "tier override lost (classifier reran)"
echo "PASS 5 --tier override"

# 6 ── --board round-trip in a throwaway backlog project (repo board untouched)
if command -v backlog >/dev/null; then
  mkdir board-proj && cd board-proj && git init -q
  backlog init --agent-instructions none --check-branches false board-proj >/dev/null 2>&1
  "$CLI" --board "selfcheck board task — create-mvp one-shot round-trip" > board.txt 2>&1 \
    || { cat board.txt >&2; fail "--board exited nonzero"; }
  id=$(grep -oE '[Tt][Aa][Ss][Kk]-[0-9]+' board.txt | head -1)
  [ -n "$id" ] || fail "--board printed no task id"
  backlog task list --plain | grep -qi "$id" || fail "created task not on the board"
  cd "$tmp"
  echo "PASS 6 --board round-trip ($id)"
else
  echo "SKIP 6 --board (no backlog CLI)"
fi

# 7 ── progress passthrough on the finished run
"$CLI" progress "$d" > prog.txt || fail "progress passthrough exited nonzero"   # capture, don't pipe: grep -q SIGPIPEs make
grep -q '100%' prog.txt || fail "progress passthrough: no 100% bar"
echo "PASS 7 progress passthrough"

echo "PASS: all create-mvp selfchecks"
