#!/usr/bin/env bash
# self-test for gate.sh: valid plan passes; empty/bad-id/dangling-dep plans fail.
set -euo pipefail
cd "$(dirname "$0")"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/valid.json" <<'EOF'
{"components":[{"id":"foo","deps":[]},{"id":"bar-baz","deps":["foo"]}]}
EOF
cat >"$tmp/empty.json" <<'EOF'
{"components":[]}
EOF
cat >"$tmp/bad-id.json" <<'EOF'
{"components":[{"id":"Bad_ID","deps":[]}]}
EOF
cat >"$tmp/dangling.json" <<'EOF'
{"components":[{"id":"foo","deps":["ghost"]}]}
EOF

fail=0
./gate.sh "$tmp/valid.json" >/dev/null || { echo "FAIL: valid plan rejected"; fail=1; }
for bad in empty bad-id dangling; do
  if ./gate.sh "$tmp/$bad.json" >/dev/null 2>&1; then
    echo "FAIL: $bad plan accepted"; fail=1
  fi
done
./gate.sh "$tmp/nonexistent.json" >/dev/null 2>&1 && { echo "FAIL: missing file accepted"; fail=1; }

[ "$fail" -eq 0 ] && echo "plan-gate: all checks passed"
exit "$fail"
