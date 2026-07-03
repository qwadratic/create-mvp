#!/usr/bin/env bash
# self-test: generate components.mk from fixture plan, grep expected rules
# and prerequisite lists, then prove parallel-safe dep-ordered build via make -j.
set -euo pipefail
cd "$(dirname "$0")"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/plan.json" <<'EOF'
{"components":[{"id":"core","deps":[]},{"id":"cli","deps":["core"]},{"id":"docs","deps":["core","cli"]}]}
EOF

# fixture must pass the plan gate (integration with sibling component)
../plan-gate/gate.sh "$tmp/plan.json" >/dev/null

./generate.sh "$tmp/plan.json" > "$tmp/components.mk"

fail=0
expect() {
  grep -qF "$1" "$tmp/components.mk" || { echo "FAIL: missing line: $1"; fail=1; }
}
expect 'COMPONENTS := core cli docs'
expect 'STAMPS := $(COMPONENTS:%=build/%.done)'
expect 'build/core.done:'
expect 'build/cli.done: build/core.done'
expect 'build/docs.done: build/core.done build/cli.done'
grep -q 'build core' "$tmp/components.mk" || { echo "FAIL: no agent build recipe"; fail=1; }

# runtime check: make -j builds stamps in dep order with a no-op agent
cat >"$tmp/Makefile" <<'EOF'
AGENT := :
include components.mk
all: $(STAMPS)
.DELETE_ON_ERROR:
EOF
( cd "$tmp" && make -j4 all >/dev/null )
for id in core cli docs; do
  [ -f "$tmp/build/$id.done" ] || { echo "FAIL: stamp missing: $id"; fail=1; }
done

# missing plan file must fail
./generate.sh "$tmp/nope.json" >/dev/null 2>&1 && { echo "FAIL: missing plan accepted"; fail=1; }

[ "$fail" -eq 0 ] && echo "components-generator: all checks passed"
exit "$fail"
