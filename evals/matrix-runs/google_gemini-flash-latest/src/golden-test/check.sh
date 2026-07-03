#!/usr/bin/env bash
set -euo pipefail

# Get directory of this script
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORDFREQ="${DIR}/../cli-integration/wordfreq.py"
INPUT_FILE="${DIR}/input.txt"
EXPECTED_FILE="${DIR}/expected.json"

ACTUAL_FILE=$(mktemp)
ACTUAL_NORM=$(mktemp)
EXPECTED_NORM=$(mktemp)

# Clean up temporary files on exit
cleanup() {
  rm -f "$ACTUAL_FILE" "$ACTUAL_NORM" "$EXPECTED_NORM"
}
trap cleanup EXIT

echo "=== Running golden-test self-test ==="

# Check that required files exist
if [ ! -f "$WORDFREQ" ]; then
  echo "Error: CLI script not found at $WORDFREQ" >&2
  exit 1
fi

if [ ! -f "$INPUT_FILE" ]; then
  echo "Error: Input file not found at $INPUT_FILE" >&2
  exit 1
fi

if [ ! -f "$EXPECTED_FILE" ]; then
  echo "Error: Expected output file not found at $EXPECTED_FILE" >&2
  exit 1
fi

# Run the CLI tool with the golden input
python3 "$WORDFREQ" --top 5 < "$INPUT_FILE" > "$ACTUAL_FILE"

# 1. Use jq to assert semantic/JSON equality first
echo "Asserting semantic JSON equality with jq..."
if ! jq --exit-status '.[0] == .[1]' <(jq -s . "$ACTUAL_FILE" "$EXPECTED_FILE") > /dev/null; then
  echo "FAIL: Output JSON structures are not semantically equivalent!" >&2
  echo "Expected:" >&2
  cat "$EXPECTED_FILE" >&2
  echo -e "\nActual:" >&2
  cat "$ACTUAL_FILE" >&2
  exit 1
fi

# 2. Use jq to canonicalize format (byte-by-byte comparison of jq-normalized strings)
echo "Canonicalizing both JSON outputs with jq..."
jq . "$EXPECTED_FILE" > "$EXPECTED_NORM"
jq . "$ACTUAL_FILE" > "$ACTUAL_NORM"

echo "Comparing actual and expected normalized outputs byte-by-byte..."
if ! cmp "$EXPECTED_NORM" "$ACTUAL_NORM"; then
  echo "FAIL: Canonicalized outputs are not byte-identical!" >&2
  echo "Diff of canonicalized output:" >&2
  diff -u "$EXPECTED_NORM" "$ACTUAL_NORM" >&2
  exit 1
fi

# 3. Direct byte-by-byte comparison of raw outputs
echo "Comparing raw outputs byte-by-byte..."
if ! cmp "$EXPECTED_FILE" "$ACTUAL_FILE"; then
  echo "FAIL: Raw outputs are not byte-identical!" >&2
  echo "Diff of raw output:" >&2
  diff -u "$EXPECTED_FILE" "$ACTUAL_FILE" >&2
  exit 1
fi

echo "Golden test PASSED successfully!"
exit 0
