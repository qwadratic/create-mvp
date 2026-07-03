#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

WORDFREQ="$ROOT/src/cli-entrypoint/wordfreq.py"
INPUT="$ROOT/src/golden-input-fixture/tests/input.txt"
EXPECTED="$ROOT/src/golden-output-fixture/tests/expected.json"

actual="$(python3 "$WORDFREQ" --top 5 < "$INPUT")"

actual_sorted="$(echo "$actual"   | jq -c 'sort_by(.count)')"
expected_sorted="$(jq -c 'sort_by(.count)' "$EXPECTED")"

if [ "$actual_sorted" = "$expected_sorted" ]; then
    echo "PASS"
    exit 0
else
    echo "FAIL"
    echo "  expected: $expected_sorted"
    echo "  actual:   $actual_sorted"
    exit 1
fi
