#!/bin/bash
set -e

# Self-test for json-formatter component
# Tests: sorting by count desc, then word asc; compact JSON output; determinism

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FORMATTER="$SCRIPT_DIR/formatter.py"

# Test 1: Basic sorting (count desc, then word asc for ties)
echo "Test 1: Basic sorting (count desc, word asc)..."
INPUT='{"apple": 5, "banana": 3, "cherry": 3, "date": 1}'
EXPECTED='[{"word":"apple","count":5},{"word":"banana","count":3},{"word":"cherry","count":3},{"word":"date","count":1}]'
OUTPUT=$(echo "$INPUT" | python3 "$FORMATTER")
if [ "$OUTPUT" != "$EXPECTED" ]; then
    echo "FAIL: Sort test"
    echo "Expected: $EXPECTED"
    echo "Got:      $OUTPUT"
    exit 1
fi
echo "  PASS"

# Test 2: Compact JSON (no spaces)
echo "Test 2: Compact JSON (no spaces)..."
INPUT='{"x": 1}'
OUTPUT=$(echo "$INPUT" | python3 "$FORMATTER")
if echo "$OUTPUT" | grep -q ' '; then
    echo "FAIL: Found whitespace in output"
    echo "Got: $OUTPUT"
    exit 1
fi
echo "  PASS"

# Test 3: Determinism (same input -> same output)
echo "Test 3: Determinism..."
INPUT='{"zebra": 2, "apple": 2, "banana": 1}'
OUTPUT1=$(echo "$INPUT" | python3 "$FORMATTER")
OUTPUT2=$(echo "$INPUT" | python3 "$FORMATTER")
if [ "$OUTPUT1" != "$OUTPUT2" ]; then
    echo "FAIL: Non-deterministic output"
    echo "Run 1: $OUTPUT1"
    echo "Run 2: $OUTPUT2"
    exit 1
fi
echo "  PASS"

# Test 4: Empty dict
echo "Test 4: Empty dict..."
INPUT='{}'
EXPECTED='[]'
OUTPUT=$(echo "$INPUT" | python3 "$FORMATTER")
if [ "$OUTPUT" != "$EXPECTED" ]; then
    echo "FAIL: Empty dict test"
    echo "Expected: $EXPECTED"
    echo "Got:      $OUTPUT"
    exit 1
fi
echo "  PASS"

# Test 5: Single entry
echo "Test 5: Single entry..."
INPUT='{"hello": 42}'
EXPECTED='[{"word":"hello","count":42}]'
OUTPUT=$(echo "$INPUT" | python3 "$FORMATTER")
if [ "$OUTPUT" != "$EXPECTED" ]; then
    echo "FAIL: Single entry test"
    echo "Expected: $EXPECTED"
    echo "Got:      $OUTPUT"
    exit 1
fi
echo "  PASS"

# Test 6: Word order for same count (alphabetical asc)
echo "Test 6: Word order for same count (alphabetical asc)..."
INPUT='{"zebra": 2, "apple": 2, "monkey": 2}'
OUTPUT=$(echo "$INPUT" | python3 "$FORMATTER")
# Should be apple, monkey, zebra
EXPECTED='[{"word":"apple","count":2},{"word":"monkey","count":2},{"word":"zebra","count":2}]'
if [ "$OUTPUT" != "$EXPECTED" ]; then
    echo "FAIL: Word order test"
    echo "Expected: $EXPECTED"
    echo "Got:      $OUTPUT"
    exit 1
fi
echo "  PASS"

echo ""
echo "All tests passed!"
exit 0
