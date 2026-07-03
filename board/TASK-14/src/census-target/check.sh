#!/usr/bin/env bash
# self-test for census.sh + census.mk. non-interactive, no network.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

cat > "$tmp/plan.json" <<'JSON'
{"components":[{"id":"core","deps":[]},{"id":"cli","deps":["core"]},{"id":"docs","deps":["cli"]}]}
JSON

mark_done() { # <dir> <id>
  mkdir -p "$1/build" "$1/out/$2"
  touch "$1/build/$2.done"
  echo built > "$1/out/$2/.built"
}

# partial: 1 of 3 done -> "1/3", exit 0
mkdir -p "$tmp/partial"; mark_done "$tmp/partial" core
out=$("$here/census.sh" "$tmp/plan.json" "$tmp/partial")
[ "$out" = "census: 1/3 done" ] || fail "partial count: $out"

# stamp without output must not count as done
touch "$tmp/partial/build/cli.done"
out=$("$here/census.sh" "$tmp/plan.json" "$tmp/partial")
[ "$out" = "census: 1/3 done" ] || fail "stamp-only counted: $out"

# complete: 3/3, exit 0
mkdir -p "$tmp/full"; for id in core cli docs; do mark_done "$tmp/full" "$id"; done
out=$("$here/census.sh" "$tmp/plan.json" "$tmp/full")
[ "$out" = "census: 3/3 done" ] || fail "full count: $out"

# missing plan -> non-zero
"$here/census.sh" "$tmp/nope.json" "$tmp/full" 2>/dev/null && fail "missing plan exit 0"

# unparsable plan -> non-zero
echo 'not json' > "$tmp/bad.json"
"$here/census.sh" "$tmp/bad.json" "$tmp/full" 2>/dev/null && fail "bad plan exit 0"

# make target: include census.mk, run in full fixture
cp "$tmp/plan.json" "$tmp/full/plan.json"
printf 'include %s\n' "$here/census.mk" > "$tmp/full/Makefile"
out=$(make -s -C "$tmp/full" census)
[ "$out" = "census: 3/3 done" ] || fail "make census: $out"

echo "census-target check: OK"
