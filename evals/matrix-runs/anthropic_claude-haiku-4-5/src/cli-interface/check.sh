#!/bin/bash
set -e

# Self-test for cli-interface component
# Tests: CLI parsing (--top N), stdin piping, component integration, slicing, determinism

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORDFREQ="$SCRIPT_DIR/wordfreq.py"

echo "Test 1: Default --top 5 (implicit)"
INPUT="apple apple apple apple apple banana banana banana cherry date date date date"
EXPECTED='[{"word":"apple","count":5},{"word":"date","count":4},{"word":"banana","count":3},{"word":"cherry","count":1}]'
OUTPUT=$(echo "$INPUT" | python3 "$WORDFREQ")
if [ "$OUTPUT" != "$EXPECTED" ]; then
    echo "FAIL: Expected top 4 items (less than default 5)"
    echo "Expected: $EXPECTED"
    echo "Got:      $OUTPUT"
    exit 1
fi
echo "  PASS"

echo "Test 2: Explicit --top 2"
INPUT="apple apple apple banana banana cherry"
EXPECTED='[{"word":"apple","count":3},{"word":"banana","count":2}]'
OUTPUT=$(echo "$INPUT" | python3 "$WORDFREQ" --top 2)
if [ "$OUTPUT" != "$EXPECTED" ]; then
    echo "FAIL: Expected top 2 items"
    echo "Expected: $EXPECTED"
    echo "Got:      $OUTPUT"
    exit 1
fi
echo "  PASS"

echo "Test 3: Slicing when N > results"
INPUT="apple banana"
EXPECTED='[{"word":"apple","count":1},{"word":"banana","count":1}]'
OUTPUT=$(echo "$INPUT" | python3 "$WORDFREQ" --top 10)
if [ "$OUTPUT" != "$EXPECTED" ]; then
    echo "FAIL: Should return all items when --top > count"
    echo "Expected: $EXPECTED"
    echo "Got:      $OUTPUT"
    exit 1
fi
echo "  PASS"

echo "Test 4: --top 0 returns empty array"
INPUT="apple banana cherry"
EXPECTED='[]'
OUTPUT=$(echo "$INPUT" | python3 "$WORDFREQ" --top 0)
if [ "$OUTPUT" != "$EXPECTED" ]; then
    echo "FAIL: Expected empty array for --top 0"
    echo "Expected: $EXPECTED"
    echo "Got:      $OUTPUT"
    exit 1
fi
echo "  PASS"

echo "Test 5: Determinism (same input -> same output)"
INPUT="zebra apple monkey apple zebra apple"
OUTPUT1=$(echo "$INPUT" | python3 "$WORDFREQ" --top 2)
OUTPUT2=$(echo "$INPUT" | python3 "$WORDFREQ" --top 2)
if [ "$OUTPUT1" != "$OUTPUT2" ]; then
    echo "FAIL: Non-deterministic output"
    echo "Run 1: $OUTPUT1"
    echo "Run 2: $OUTPUT2"
    exit 1
fi
echo "  PASS"

echo "Test 6: Sorting by count desc, word asc (tie-breaking)"
INPUT="zebra zebra apple apple monkey monkey"
EXPECTED='[{"word":"apple","count":2},{"word":"monkey","count":2},{"word":"zebra","count":2}]'
OUTPUT=$(echo "$INPUT" | python3 "$WORDFREQ" --top 3)
if [ "$OUTPUT" != "$EXPECTED" ]; then
    echo "FAIL: Expected alphabetical order for ties"
    echo "Expected: $EXPECTED"
    echo "Got:      $OUTPUT"
    exit 1
fi
echo "  PASS"

echo "Test 7: Compact JSON (no spaces)"
INPUT="test test test"
OUTPUT=$(echo "$INPUT" | python3 "$WORDFREQ" --top 1)
if echo "$OUTPUT" | grep -q ' '; then
    echo "FAIL: Found whitespace in output"
    echo "Got: $OUTPUT"
    exit 1
fi
echo "  PASS"

echo "Test 8: Empty input"
INPUT=""
EXPECTED='[]'
OUTPUT=$(echo "$INPUT" | python3 "$WORDFREQ" --top 5)
if [ "$OUTPUT" != "$EXPECTED" ]; then
    echo "FAIL: Expected empty array for empty input"
    echo "Expected: $EXPECTED"
    echo "Got:      $OUTPUT"
    exit 1
fi
echo "  PASS"

echo "Test 9: Non-letter splitting (numbers, punctuation)"
INPUT="hello-world! test_case 123abc"
EXPECTED='[{"word":"abc","count":1},{"word":"case","count":1},{"word":"hello","count":1},{"word":"test","count":1},{"word":"world","count":1}]'
OUTPUT=$(echo "$INPUT" | python3 "$WORDFREQ" --top 5)
if [ "$OUTPUT" != "$EXPECTED" ]; then
    echo "FAIL: Non-letter splitting"
    echo "Expected: $EXPECTED"
    echo "Got:      $OUTPUT"
    exit 1
fi
echo "  PASS"

echo "Test 10: Case insensitivity"
INPUT="Hello HELLO hello HeLLo"
EXPECTED='[{"word":"hello","count":4}]'
OUTPUT=$(echo "$INPUT" | python3 "$WORDFREQ" --top 5)
if [ "$OUTPUT" != "$EXPECTED" ]; then
    echo "FAIL: Case insensitivity"
    echo "Expected: $EXPECTED"
    echo "Got:      $OUTPUT"
    exit 1
fi
echo "  PASS"

echo ""
echo "All tests passed!"
exit 0
