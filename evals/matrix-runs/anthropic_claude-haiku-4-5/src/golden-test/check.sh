#!/bin/bash
set -e

# Golden test: fixed input + golden.json expected output
# Verifies determinism by comparing byte-identical output via jq -S

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INPUT="$SCRIPT_DIR/input.txt"
GOLDEN="$SCRIPT_DIR/golden.json"
WORDFREQ="$SCRIPT_DIR/../cli-interface/wordfreq.py"

# Verify input and golden files exist
if [ ! -f "$INPUT" ]; then
    echo "ERROR: Input file not found: $INPUT"
    exit 1
fi

if [ ! -f "$GOLDEN" ]; then
    echo "ERROR: Golden file not found: $GOLDEN"
    exit 1
fi

if [ ! -f "$WORDFREQ" ]; then
    echo "ERROR: CLI interface not found: $WORDFREQ"
    exit 1
fi

# Run CLI and pipe through jq -S for canonical form
OUTPUT=$(cat "$INPUT" | python3 "$WORDFREQ" --top 5 | jq -S .)

# Read golden file
EXPECTED=$(cat "$GOLDEN")

# Compare byte-identical
if [ "$OUTPUT" != "$EXPECTED" ]; then
    echo "FAIL: Output does not match golden.json"
    echo ""
    echo "Expected:"
    echo "$EXPECTED"
    echo ""
    echo "Got:"
    echo "$OUTPUT"
    exit 1
fi

echo "PASS: Golden test - output byte-identical with golden.json"
exit 0
