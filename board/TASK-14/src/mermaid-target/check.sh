#!/usr/bin/env bash
# self-test: generate mermaid from fixture plan, diff against expected text;
# also exercise the make 'graph' target and error path.
set -euo pipefail
cd "$(dirname "$0")"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/plan.json" <<'EOF'
{"components":[{"id":"core","deps":[]},{"id":"cli","deps":["core"]},{"id":"docs","deps":["core","cli"]}]}
EOF

cat >"$tmp/expected.mmd" <<'EOF'
graph TD
  core
  core --> cli
  core --> docs
  cli --> docs
EOF

fail=0

./graph.sh "$tmp/plan.json" > "$tmp/got.mmd"
diff -u "$tmp/expected.mmd" "$tmp/got.mmd" || { echo "FAIL: mermaid mismatch"; fail=1; }

# make 'graph' target integration
here=$(pwd)
( cd "$tmp" && env -u MAKEFLAGS -u MAKELEVEL make -s -f "$here/graph.mk" graph PLAN="$tmp/plan.json" ) > "$tmp/got2.mmd"
diff -u "$tmp/expected.mmd" "$tmp/got2.mmd" || { echo "FAIL: make graph mismatch"; fail=1; }

# missing plan must fail
./graph.sh "$tmp/nope.json" >/dev/null 2>&1 && { echo "FAIL: missing plan accepted"; fail=1; }

# integration: real build/plan.json (if present) round-trips through gate + graph
if [ -f ../../build/plan.json ]; then
  ../plan-gate/gate.sh ../../build/plan.json >/dev/null
  ./graph.sh ../../build/plan.json | head -1 | grep -qx 'graph TD' || { echo "FAIL: real plan graph"; fail=1; }
fi

[ "$fail" -eq 0 ] && echo "mermaid-target: all checks passed"
exit "$fail"
