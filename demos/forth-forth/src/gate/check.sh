#!/bin/sh
# stage-2 equivalence gate: interpreted == compiled == golden, byte-exact
set -eu
cd "$(dirname "$0")/../.."
mkdir -p build-out

for t in fib fizzbuzz stackops; do
  golden="src/tests/golden/$t.out"

  # 1. interpreted via stage0
  python3 src/stage0/stage0.py "src/tests/$t.fs" > "build-out/$t.interp.out"
  cmp "$golden" "build-out/$t.interp.out" || { echo "FAIL: $t interpreted != golden" >&2; exit 1; }

  # 2. compile via stage1
  python3 src/stage0/stage0.py src/stage1/compiler.fs "src/tests/$t.fs" > "build-out/$t.py"

  # 3. run compiled
  python3 "build-out/$t.py" > "build-out/$t.compiled.out"
  cmp "$golden" "build-out/$t.compiled.out" || { echo "FAIL: $t compiled != golden" >&2; exit 1; }

  echo "OK: $t"
done

echo "gate: all tests pass (interpreted == compiled == golden)"
