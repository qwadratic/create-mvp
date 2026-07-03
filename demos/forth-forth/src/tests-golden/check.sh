#!/bin/sh
# tests-golden check: 6 files exist, goldens match pinned bytes from spec.
set -u
cd "$(dirname "$0")/../.."

fail=0

for f in src/tests/fib.fs src/tests/fizzbuzz.fs src/tests/stackops.fs \
         src/tests/golden/fib.out src/tests/golden/fizzbuzz.out src/tests/golden/stackops.out; do
  [ -f "$f" ] || { echo "MISSING: $f"; fail=1; }
done
[ "$fail" -eq 0 ] || exit 1

tmp=$(mktemp) || exit 1
trap 'rm -f "$tmp"' EXIT

check() {
  # $1 = golden file; expected bytes on stdin
  cat > "$tmp"
  if cmp -s "$tmp" "$1"; then
    echo "OK: $1"
  else
    echo "MISMATCH: $1"
    fail=1
  fi
}

# NOTE: number lines end in exactly one trailing space (pinned in spec).
check src/tests/golden/fib.out <<'EOF'
0 1 1 2 3 5 8 13 21 34 
EOF

check src/tests/golden/fizzbuzz.out <<'EOF'
1 
2 
Fizz
4 
Buzz
Fizz
7 
8 
Fizz
Buzz
11 
Fizz
13 
14 
FizzBuzz
EOF

check src/tests/golden/stackops.out <<'EOF'
1 3 2 
4 5 
12 
7 8 7 
7 1 6 
-1 -1 -1 
EOF

# byte-count sanity (pinned): fib=24 fizzbuzz=66 stackops=40
for spec in "src/tests/golden/fib.out 24" "src/tests/golden/fizzbuzz.out 66" "src/tests/golden/stackops.out 40"; do
  f=${spec% *}; want=${spec#* }
  got=$(wc -c < "$f" | tr -d ' ')
  if [ "$got" != "$want" ]; then
    echo "BAD SIZE: $f got=$got want=$want"
    fail=1
  fi
done

exit "$fail"
