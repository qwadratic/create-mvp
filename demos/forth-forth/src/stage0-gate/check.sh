#!/bin/sh
# stage0-gate: stage0 interprets pinned tests byte-exact vs goldens.
set -e
cd "$(dirname "$0")/../.."
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
for t in fib fizzbuzz stackops; do
  python3 src/stage0/stage0.py "src/tests/$t.fs" > "$tmp/$t.out"
  cmp "$tmp/$t.out" "src/tests/golden/$t.out" || { echo "FAIL: $t" >&2; exit 1; }
  echo "OK: $t"
done
