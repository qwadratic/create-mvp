#!/usr/bin/env bash
# e2e-check: run produced engine end-to-end with stub agent. No network, no LLM.
# gate passes -> make -j builds in dep order -> census all done -> graph valid mermaid.
set -euo pipefail
unset MAKEFLAGS MFLAGS MAKELEVEL 2>/dev/null || true

here="$(cd "$(dirname "$0")" && pwd)"
src="$here/.."
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cd "$tmp"

fail() { echo "FAIL: $*" >&2; exit 1; }

# trivial example goal
echo "build a tiny tool with core, cli and docs" > goal.md

# wrapper makefile: engine core + census + graph targets
# CENSUS pinned: census.mk uses deferred ?= that mis-resolves after later includes
cat > Makefile <<EOF
CENSUS := $src/census-target/census.sh
include $src/engine-core-makefile/Makefile
include $src/census-target/census.mk
include $src/mermaid-target/graph.mk
EOF

# 1. end-to-end parallel build (plan -> gate -> components.mk -> stamps)
log="$(make -j4 2>&1)" || { echo "$log"; fail "make -j4 exited non-zero"; }

# plan gate passed inside make; re-check explicitly on produced plan
[ -f plan.json ] || fail "plan.json not produced"
"$src/plan-gate/gate.sh" plan.json || fail "plan gate rejected produced plan.json"

# 2. dependency order: core before cli before docs in build log
pos() { grep -n "build $1\$" <<<"$log" | head -1 | cut -d: -f1; }
p_core=$(pos core); p_cli=$(pos cli); p_docs=$(pos docs)
[ -n "$p_core" ] && [ -n "$p_cli" ] && [ -n "$p_docs" ] \
  || { echo "$log"; fail "missing build line in log"; }
[ "$p_core" -lt "$p_cli" ] && [ "$p_cli" -lt "$p_docs" ] \
  || { echo "$log"; fail "build log out of dependency order"; }

# stamp mtimes agree with order (allow equal within same second)
[ ! build/core.done -nt build/cli.done ]  || fail "stamp mtime: core newer than cli"
[ ! build/cli.done  -nt build/docs.done ] || fail "stamp mtime: cli newer than docs"

# 3. census reports all done
census_out="$(make -s census)" || fail "census target errored"
[ "$census_out" = "census: 3/3 done" ] || fail "census wrong: $census_out"

# 4. graph target emits valid mermaid
graph_out="$(make -s graph)" || fail "graph target errored"
[ "$(head -1 <<<"$graph_out")" = "graph TD" ] || fail "graph missing 'graph TD' header"
grep -q '^  core --> cli$'  <<<"$graph_out" || fail "graph missing edge core --> cli"
grep -q '^  cli --> docs$'  <<<"$graph_out" || fail "graph missing edge cli --> docs"
grep -q '^  core --> docs$' <<<"$graph_out" || fail "graph missing edge core --> docs"

echo "OK: e2e-check"
