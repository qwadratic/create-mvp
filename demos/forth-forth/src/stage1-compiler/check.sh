#!/bin/sh
# stage1-compiler check: compile a non-pinned smoke program, run emitted .py,
# byte-compare against the same program interpreted under stage0.
set -eu
cd "$(dirname "$0")/../.."

# criterion 2 sanity: compiler.fs must contain zero Python
if grep -qE '^(import |def |class |print\()' src/stage1/compiler.fs; then
  echo "FAIL: python-looking lines in src/stage1/compiler.fs" >&2
  exit 1
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

python3 src/stage0/stage0.py src/stage1-compiler/smoke.fs > "$tmp/interp.out"
python3 src/stage0/stage0.py src/stage1/compiler.fs src/stage1-compiler/smoke.fs > "$tmp/smoke.py"
python3 "$tmp/smoke.py" > "$tmp/compiled.out"

cmp "$tmp/interp.out" "$tmp/compiled.out" || {
  echo "FAIL: compiled output differs from interpreted output" >&2
  exit 1
}
echo "stage1-compiler: OK (interpreted == compiled on smoke test)"
