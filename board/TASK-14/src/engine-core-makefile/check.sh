#!/usr/bin/env bash
# self-test: dry-run make -n on fixture shows correct rule chain, then real -j build
set -euo pipefail
unset MAKEFLAGS MFLAGS MAKELEVEL 2>/dev/null || true
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
cd "$tmp"
echo "trivial example goal" > goal.md

# dry run: make still remakes plan.json + components.mk (include restart), but only prints build rules
out="$(make -n -f "$here/Makefile" 2>&1)" || { echo "$out"; echo "FAIL: make -n exited non-zero"; exit 1; }

[ -f plan.json ]      || { echo "FAIL: plan.json not generated"; exit 1; }
[ -f components.mk ]  || { echo "FAIL: components.mk not generated (no re-include restart)"; exit 1; }
grep -q '.DELETE_ON_ERROR' "$here/Makefile" || { echo "FAIL: .DELETE_ON_ERROR missing"; exit 1; }

# rule chain order: core before cli before docs (stub plan deps)
pos() { grep -n "build $1\$" <<<"$out" | head -1 | cut -d: -f1; }
p_core=$(pos core); p_cli=$(pos cli); p_docs=$(pos docs)
[ -n "$p_core" ] && [ -n "$p_cli" ] && [ -n "$p_docs" ] || { echo "$out"; echo "FAIL: missing build rule in -n output"; exit 1; }
[ "$p_core" -lt "$p_cli" ] && [ "$p_cli" -lt "$p_docs" ] || { echo "FAIL: rule chain out of dep order"; exit 1; }

# dry run must not create stamps
[ ! -e build/core.done ] || { echo "FAIL: dry run created stamp"; exit 1; }

# real parallel build: stamps + artifacts exist
make -j4 -f "$here/Makefile" >/dev/null
for id in core cli docs; do
  [ -f "build/$id.done" ] || { echo "FAIL: missing stamp build/$id.done"; exit 1; }
  [ -x "out/$id/main.sh" ] || { echo "FAIL: missing artifact out/$id/main.sh"; exit 1; }
done

# idempotent: second run is a no-op
make -f "$here/Makefile" | grep -q 'Nothing to be done\|up to date' || { echo "FAIL: rebuild not idempotent"; exit 1; }

echo "OK: engine-core-makefile"
